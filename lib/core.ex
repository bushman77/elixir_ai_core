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

  # alias LexiconEnricher   # ← not needed in this module anymore (Brain handles enrichment)
  # alias MoodCore          # keep if used below


  @spec infer(Axon.Model.t(), Nx.Tensor.t() | list()) :: any()
  def infer(nil, _input), do: {:error, :no_model_loaded}
  def infer(model, input) do
    input_tensor = Nx.tensor(input)
    {compiled_model, params} = model
    Axon.predict(compiled_model, params, input_tensor)
  end

  # ── SAFE ACTIVATION: single site, filtered, time-bounded ─────────────────────

def activate_tokens(%SemanticInput{token_structs: tokens} = semantic) do
  phrases =
    tokens
    |> Enum.map(& &1.phrase)
    |> Enum.uniq()
    |> Enum.reject(&skip_activation?/1)

  Task.Supervisor.async_stream_nolink(
    Core.TaskSup, phrases, &Brain.get_or_start/1,
    max_concurrency: 4, timeout: 3_000, on_timeout: :kill_task
  )
  |> Stream.run()

  # fill attention (use only the tokens we didn’t skip)
  kept_tokens = Enum.filter(tokens, fn t -> not skip_activation?(t.phrase) end)
  _cells = Brain.attention(kept_tokens)

  semantic
end

  # Functional phrases (e.g., "what is", "see you"), multiword phrases, and tiny tokens
  # should NEVER trigger enrichment or process starts.
  defp skip_activation?(p) do
    String.length(p) < 3 or String.contains?(p, " ") or match?([_ | _], Core.MultiwordPOS.lookup(p))
  end

  @doc """
  Master pipeline: from raw input to fully processed SemanticInput.
  """
# in lib/core.ex, inside resolve_input/1
def resolve_input(input) when is_binary(input) do
  input
  |> Tokenizer.tokenize()
  |> SemanticInput.sanitize()
  |> then(fn sem ->
    # 1) warm/start single-word cells (your Brain.get_or_start/1 already skips multiword/short/functional)
    Enum.each(sem.token_structs, fn t -> Brain.get_or_start(t.phrase) end)

    # 2) register attention (this also logs activations via your handle_call/3)
    Brain.attention(sem.token_structs)
    sem
  end)
  # (optional) keep if it does other work; otherwise you can delete it
  |> Core.activate_tokens()
  |> POSEngine.tag()
  |> then(fn sem ->
    chosen = POSDisambiguator.disambiguate(sem.token_structs)
    Map.put(sem, :chosen_cells, chosen)   # %{index => %BrainCell{}}
  end)
  |> IntentClassifier.classify_tokens()
  |> IntentResolver.resolve_intent()
  |> FRP.Features.attach_features()
  |> IntentResolver.refine_with_pos_profiles()
  |> Brain.prune_by_intent_pos()
  |> MoodCore.attach_mood()
  |> ResponsePlanner.analyze()
  |> then(&{:ok, &1})
end

  # ── DEPRECATED / NO-OP ACTIVATION HELPERS ────────────────────────────────────
  # These used to recurse + enrich. That caused the lockups on "what is"/"see you".
  # Keep them as no-ops or pure lookups if other code still calls them.

  # Token → (no side effects) return as-is; activation is centralized above.
  def activate_cells(%Token{} = token), do: token

  # Token → attach a DB cell if already present; DO NOT start/enrich here.
  def update_token_with_cell(%Token{phrase: phrase} = token) do
    case Brain.get_all(phrase) do
      [%BrainCell{} = cell | _] ->
        %{token | cell: cell, pos: cell.pos, keyword: cell.word}

      _ ->
        Logger.debug("No BrainCell found for #{inspect(phrase)} (skipping)")
        token
    end
  end

  # Optional legacy helpers (left intact if referenced elsewhere)
  def resolve_and_classify(input), do: resolve_input(input)
end

