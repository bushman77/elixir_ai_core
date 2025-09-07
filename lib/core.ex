defmodule Core do
  @moduledoc "Central Core pipeline for tokenizing, linking, classifying, and planning AI behavior."

  require Logger
  import Nx.Defn

  alias Axon
  alias Brain
  alias BrainCell

  alias Core.{
    Tokenizer,
    IntentClassifier,
    IntentResolver,
    IntentPOSProfile,
    POSDisambiguator,
    POSEngine,
    ResponsePlanner,
    SemanticInput,
    Token,
    DB
  }

  alias FRP.Features
  alias MoodCore
  alias Core.MultiwordPOS

  @spec infer(Axon.Model.t(), Nx.Tensor.t() | list()) :: any()
  def infer(nil, _input), do: {:error, :no_model_loaded}
  def infer(model, input) do
    input_tensor = Nx.tensor(input)
    {compiled_model, params} = model
    Axon.predict(compiled_model, params, input_tensor)
  end

  @doc """
  Master pipeline: from raw input to fully processed SemanticInput.
  Multiword phrases are segmented *before* tokenization, ensured/started *before* intent,
  and all DB access goes through Core.DB (no direct Ecto here).
  """
  @spec resolve_input(String.t(), atom()) :: {:ok, SemanticInput.t()} | {:error, term()}
  def resolve_input(input, source \\ :console) when is_binary(input) do
    # 1) Greedy segmentation with DB-first knowledge + MW lexicon hint
    segs = segment_phrases(input)

    # 2) Tokenize from segments if available; otherwise fall back to existing tokenizer
    sem =
      try do
        Tokenizer.from_segments(segs, source)
      rescue
        _ ->
          input
          |> Tokenizer.tokenize()
          |> SemanticInput.sanitize()
          |> Map.put(:source, source)
      end

    # 3) PRE-INTENT: ensure rows & start processes for lexical multiwords + words
# Build phrase→pos map from produced tokens
pos_by_phrase =
  sem.token_structs
  |> Enum.reduce(%{}, fn t, acc -> Map.put_new(acc, normalize(t.phrase), Map.get(t, :pos)) end)

activation_candidates =
  (segs |> Enum.map(& &1.text)) ++ (sem.token_structs |> Enum.map(& &1.phrase))
  |> Enum.map(&normalize/1)
  |> Enum.uniq()
  |> Enum.filter(&allow_activation?/1)

Logger.info("Activating: #{inspect(activation_candidates)}")

Enum.each(activation_candidates, fn ph ->
  ret =
    if function_exported?(Brain, :get_or_start, 2) do
      Brain.get_or_start(ph, Map.get(pos_by_phrase, ph))
    else
      Brain.get_or_start(ph)
    end

  pid =
    case ret do
      {:ok, p} when is_pid(p) -> p
      {:ok, {p, _meta}} when is_pid(p) -> p
      {:error, {:already_started, p}} when is_pid(p) -> p
      {:ok, [p | _]} when is_pid(p) -> p
      {:ok, list} when is_list(list) -> first_alive(list)
      p when is_pid(p) -> p
      _ ->
        registry_pid_candidates(ph, Map.get(pos_by_phrase, ph))
        |> first_alive()
    end

  if is_pid(pid) and function_exported?(Brain, :register_active, 2) do
    Brain.register_active(ph, pid)
  end
end)

# Always update attention (guarantees activation_log even on a cold start)
attention_tokens =
  activation_candidates
  |> Enum.map(fn ph -> %Token{text: ph, phrase: ph, pos: Map.get(pos_by_phrase, ph)} end)

Brain.attention(attention_tokens)

    # 4) Downstream POS + Intent
    sem
    |> POSEngine.tag()
    |> then(fn sem2 ->
      chosen = POSDisambiguator.disambiguate(sem2.token_structs)
      Map.put(sem2, :chosen_cells, chosen) # %{index => %BrainCell{}}
    end)
    |> IntentClassifier.classify_tokens()
    |> IntentResolver.resolve_intent()
    |> Features.attach_features()
    |> IntentResolver.refine_with_pos_profiles()
    |> Brain.prune_by_intent_pos()
    |> MoodCore.attach_mood()
    |> ResponsePlanner.analyze()
    |> then(&{:ok, &1})
  end

  # =====================
  # SEGMENTATION (PRIVATE)
  # =====================
  # Produces: [%{type: :phrase, text: "new york city"}, %{type: :word, text: "subway"}, ...]
  defp segment_phrases(sentence) do
    words =
      Regex.scan(~r/\p{L}+|\d+|[^\s\p{L}\d]+/u, sentence)
      |> Enum.map(&hd/1)

    max_n = 5
    do_segment(words, 0, max_n, []) |> Enum.reverse()
  end

  defp do_segment(words, i, max_n, acc) when i >= length(words), do: acc

  defp do_segment(words, i, max_n, acc) do
    end_idx = min(length(words), i + max_n)

    {hit_phrase, span} =
      i..(end_idx - 1)
      |> Enum.reverse()
      |> Enum.find_value({nil, 0}, fn j ->
        phrase =
          words
          |> Enum.slice(i..j)
          |> Enum.join(" ")
          |> normalize()

        if phrase_known_locally?(phrase), do: {phrase, j - i + 1}, else: nil
      end) || {nil, 0}

    if hit_phrase do
      do_segment(words, i + span, max_n, [%{type: :phrase, text: hit_phrase} | acc])
    else
      w = normalize(Enum.at(words, i))
      do_segment(words, i + 1, max_n, [%{type: :word, text: w} | acc])
    end
  end

  # Normalization used everywhere for keys/activation
  defp normalize(s), do: s |> String.downcase() |> String.trim()

  # ---- Local knowledge: DB-first via Core.DB, then Multiword lexicon hint ----
  defp phrase_known_locally?(phrase), do: db_has_word?(phrase) or multiword_hint?(phrase)

  # Single DB touchpoint — implement in Core.DB: exists_word?/1 -> true/false
  defp db_has_word?(phrase) do
    try do
      DB.exists_word?(phrase)
    rescue
      _ -> false
    end
  end

  defp multiword_hint?(phrase) do
    try do
      case MultiwordPOS.lookup(phrase) do
        l when is_list(l) and l != [] -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  # ===================
  # ACTIVATION POLICIES
  # ===================
  # Allow lexical multiwords and single words; skip functional templates like "what is".
  defp allow_activation?(phrase) do
    is_single = not String.contains?(phrase, " ")
    cond do
      is_single -> String.length(phrase) >= 2
      lexical_multiword?(phrase) -> true
      true -> false
    end
  end

  defp lexical_multiword?(phrase) do
    try do
      case MultiwordPOS.lookup(phrase) do
        tags when is_list(tags) ->
          Enum.any?(tags, &(&1 in [:idiom, :noun_phrase, :phrasal_verb, :proper_noun]))
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  # ---- Legacy helpers kept intact (no direct DB usage here) ----
  def activate_cells(%Token{} = token), do: token

  def update_token_with_cell(%Token{phrase: phrase} = token) do
    case Brain.get_all(phrase) do
      [%BrainCell{} = cell | _] ->
        %{token | cell: cell, pos: cell.pos, keyword: cell.word}
      _ ->
        Logger.debug("No BrainCell found for #{inspect(phrase)} (skipping)")
        token
    end
  end

  # Optional legacy helper
  def resolve_and_classify(input), do: resolve_input(input)

  # --- Brain starter (handles /1 or /2 arity) ---
  defp start_cell(phrase), do: start_cell(phrase, nil)
  defp start_cell(phrase, pos) do
    cond do
      function_exported?(Brain, :get_or_start, 2) -> Brain.get_or_start(phrase, pos)
      function_exported?(Brain, :get_or_start, 1) -> Brain.get_or_start(phrase)
      true ->
        Logger.error("Brain.get_or_start/1 or /2 not found")
        :error
    end
  end

  # Try a few plausible registry keys to find the cell PID if get_or_start didn't return one
  defp registry_pid_candidates(phrase, pos) do
    base = normalize(phrase)

    [
      base,
      (pos && "#{base}|#{pos}"),
      (pos && "#{base}|#{pos}|0")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&lookup_registry_pid/1)
  end

 defp lookup_registry_pid(id) do
  cond do
    # Prefer Brain.whereis/1 if you've got it
    Code.ensure_loaded?(Brain) and function_exported?(Brain, :whereis, 1) ->
      case Brain.whereis(id) do
        pid when is_pid(pid) -> pid
        _ -> nil
      end

    # Fallback: look directly in Core.Registry, only if it's actually started
    function_exported?(Registry, :lookup, 2) and is_pid(Process.whereis(Core.Registry)) ->
      case Registry.lookup(Core.Registry, id) do
        [{pid, _} | _] -> pid
        _ -> nil
      end

    true ->
      nil
  end
end
 
  defp first_alive(list) do
    Enum.find(list, fn
      pid when is_pid(pid) -> Process.alive?(pid)
      _ -> false
    end)
  end
end

