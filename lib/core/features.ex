defmodule FRP.Features do
  @moduledoc """
  Minimal, dependency-free feature builder for FRP.

  Input: %Core.SemanticInput{
    sentence: String.t(),
    tokens: [String.t()] | nil,
    pos_list: [atom() | String.t()] | nil,
    intent: atom() | nil,
    confidence: float() | nil
  }

  Output: {Nx tensor of shape {1, 128}, meta :: map()}
  The 128-dim vector is stable and safe to feed into FRP.Model.
  """

  alias Nx, as: Nx
  @n_in 128
  def n_in(), do: @n_in

  # Keep tiny fixed vocabularies so one-hot sizes are stable
  @intents [:greeting, :question, :how_to, :troubleshoot, :request, :confirm, :thanks, :goodbye, :insult, :unknown]
  @pos_tags [:noun, :verb, :adj, :adv, :pron, :det, :aux, :adp, :conj, :num, :part, :intj, :punct]

  @doc """
  Build a 128-d row vector from SemanticInput.
  """
  def build(%{sentence: s} = sem, _opts \\ []) when is_binary(s) do
    text = s
    tokens = sem.tokens || []
    pos_list = sem.pos_list || []
    conf = clamp(sem.confidence || 0.0)

    # --- basic text stats ---
    wc = max(Enum.count(String.split(text)), 1)
    len_norm = clamp(byte_size(text) / 500)
    wc_norm  = clamp(wc / 100)

    punct_total =
      ["?", "!", ",", "."]
      |> Enum.map(&count(text, &1))
      |> Enum.sum()
      |> max(1)

    q_ratio  = clamp(count(text, "?") / punct_total)
    ex_ratio = clamp(count(text, "!") / punct_total)

    upper_ratio = clamp(uppercase_ratio(text))
    second_person = ratio(text, ~r/\b(you|your|u)\b/i)
    has_code = if String.contains?(text, ["```", "`"]), do: 1.0, else: 0.0
    has_url  = if String.contains?(text, ["http://", "https://"]), do: 1.0, else: 0.0

    # --- POS histogram (normalized) ---
    pos_hist = pos_histogram(pos_list, @pos_tags)

    # --- Intent one-hot ---
    intent_ix = index_of(@intents, sem.intent || :unknown)
    intent_hot = one_hot(intent_ix, length(@intents))

    # --- token stats ---
    avg_token_len =
      case tokens do
        [] -> 0.0
        list -> list |> Enum.map(&String.length/1) |> then(fn lens -> Enum.sum(lens) / length(lens) end) |> Kernel./(12) |> clamp()
      end

    # Compose feature vector (add more later as needed)
    base_vec =
      [
        len_norm, wc_norm, q_ratio, ex_ratio, upper_ratio, second_person,
        has_code, has_url, conf, avg_token_len
      ] ++ pos_hist ++ intent_hot

    # Pad/trim to 128 dims
    vec =
      cond do
        length(base_vec) == @n_in -> base_vec
        length(base_vec) <  @n_in -> base_vec ++ List.duplicate(0.0, @n_in - length(base_vec))
        true -> Enum.take(base_vec, @n_in)
      end

    {Nx.tensor([vec], type: {:f, 32}), %{intent_ix: intent_ix}}
  end

  # ----- helpers -----

  defp clamp(x) when is_number(x), do: x |> max(0.0) |> min(1.0)

  defp count(text, needle) do
    text
    |> String.split(needle)
    |> length()
    |> Kernel.-(1)
    |> max(0)
  end

  defp uppercase_ratio(text) do
    {u, a} =
      text
      |> String.to_charlist()
      |> Enum.reduce({0, 0}, fn ch, {u, a} ->
        cond do
          ch in ?A..?Z -> {u + 1, a + 1}
          ch in ?a..?z -> {u, a + 1}
          true -> {u, a}
        end
      end)

    if a == 0, do: 0.0, else: u / a |> clamp()
  end

  defp ratio(text, regex) do
    total = max(Enum.count(String.split(text)), 1)
    hits = Regex.scan(regex, text) |> length()
    clamp(hits / total)
  end

  defp pos_histogram(pos_list, tags) do
    counts =
      Enum.reduce(pos_list, %{}, fn t, acc -> Map.update(acc, normalize_pos(t), 1, &(&1 + 1)) end)

    total = counts |> Map.values() |> Enum.sum() |> max(1)

    Enum.map(tags, fn tag ->
      v = Map.get(counts, tag, 0)
      clamp(v / total)
    end)
  end

  defp normalize_pos(t) when is_atom(t) do
    allowed = MapSet.new([:noun, :verb, :adj, :adv, :pron, :det, :aux,
                          :adp, :conj, :num, :part, :intj, :punct])
    if MapSet.member?(allowed, t), do: t, else: :punct
  end

  defp normalize_pos(t) when is_binary(t) do
    case String.downcase(t) do
      "adjective" -> :adj
      "adverb" -> :adv
      "interjection" -> :intj
      "preposition" -> :adp
      "postposition" -> :adp
      "determiner" -> :det
      "conjunction" -> :conj
      "numeral" -> :num
      "particle" -> :part
      "punctuation" -> :punct
      x when x in ~w(noun verb adj adv pron det aux adp conj num part intj punct) ->
        String.to_atom(x)
      _ -> :punct
    end
  end

  defp normalize_pos(_), do: :punct
  defp index_of(list, atom) do
    case Enum.find_index(list, &(&1 == atom)) do
      nil -> nil
      ix -> ix
    end
  end

  defp one_hot(nil, n), do: List.duplicate(0.0, n)
  defp one_hot(ix, n), do: for i <- 0..(n - 1), do: if(i == ix, do: 1.0, else: 0.0)
end

