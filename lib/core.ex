defmodule Core do
  @moduledoc "Central Core pipeline for tokenizing, linking, classifying, and planning AI behavior."

  require Logger

  alias Core.{
    Tokenizer,
    IntentClassifier,
    IntentResolver,
    POSEngine,
    ResponsePlanner,
    SemanticInput,
    Token,
    DB
  }

  alias LexiconEnricher
  alias MoodCore
  alias Brain
  alias BrainCell


def activate_tokens(%SemanticInput{token_structs: tokens} = semantic) do
  updated_tokens =
    Enum.map(tokens, fn token ->
      activated = activate_cells(token)
      Brain.get_or_start(activated.phrase)
      activated
    end)

  %{semantic | token_structs: updated_tokens}
end

  @doc """
  Master pipeline: from raw input to fully processed SemanticInput.
  """

def resolve_input(input) when is_binary(input) do
  input
  |> Tokenizer.tokenize()                   # builds SemanticInput from string
  |> Core.activate_tokens()                 # applies Brain.get / activation
  |> POSEngine.tag()                        # updates token_structs with POS
  #|> Core.update_token_phrases()            # ensures phrases are correct after tagging
  |> IntentClassifier.classify_tokens()     # adds intent, keyword, confidence
  |> IntentResolver.resolve_intent()        # resolves final intent from matrix
  |> MoodCore.attach_mood()                 # modulates mood + records state
  |> ResponsePlanner.analyze()              # plans response structure
  |> then(&{:ok, &1})
end

  # Token → ensure BrainCell is started
  def activate_cells(%Token{phrase: phrase} = token) do
    case Brain.get_all(phrase) do
      [] -> token
      cells ->
        Enum.each(cells, &Brain.ensure_started/1)
        token
    end
  end

  # Token → attach BrainCell info (pos, keyword, etc.)
  def update_token_with_cell(%Token{phrase: phrase} = token) do
    case Brain.get_all(phrase) do
      [%BrainCell{} = cell | _] ->
        Brain.ensure_running(cell)
        %{token | cell: cell, pos: cell.pos, keyword: cell.word}

      _ ->
        Logger.warning("⚠️ No BrainCell found for #{inspect(phrase)}")
        token
    end
  end

  # Deprecated: separate enrich call (handled now in other flows)
  defp enrich_if_missing(word) do
    case LexiconEnricher.enrich(word) do
      {:ok, cells} ->
        Enum.each(cells, &store_cell/1)
        cells

      {:error, reason} ->
        Logger.warning("⚠️ Enrichment failed for '#{word}': #{inspect(reason)}")
        []
    end
  end

  defp store_cell(%BrainCell{} = cell) do
    normalized =
      cell
      |> Map.from_struct()
      |> Map.drop([:__meta__, :__struct__])
      |> then(&struct(BrainCell, &1))

    unless DB.cell_exists?(normalized.id) do
      DB.insert_cell!(normalized)
    end

    Brain.store(normalized)
  end

  # (Optional) legacy fallback hook
  def resolve_and_classify(input), do: resolve_input(input)
end

