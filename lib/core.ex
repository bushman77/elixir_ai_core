defmodule Core do
  require Logger
  alias Core.{Tokenizer, IntentResolver, Token, DB}
  alias LexiconEnricher
alias Core.SemanticInput
alias Core.POSEngine
alias Core.IntentClassifier
alias Core.ResponsePlanner

def get_cells(%Token{phrase: phrase}) when is_binary(phrase) do
  Brain.get_state().active_cells
  |> Map.keys()
  |> Enum.filter(fn key ->
    String.starts_with?(key, "#{phrase}|")
  end)
  |> Enum.map(&Brain.get_by_key/1)
  |> Enum.filter(& &1)  # Remove any nils
end

  @doc "Entry point for resolving raw input (string)"
  def resolve_input(input) when is_binary(input) do
    tokens =
      input
      |> Tokenizer.tokenize()
      |> Enum.map(fn
        %Token{} = t -> t
        str -> %Token{phrase: str}
      end)
      |> Enum.map(&activate_cells/1)

    brain_cells =
      tokens
      |> Enum.filter(& &1)

    active = Brain.get_state.active_cells
    |> Map.keys

    #check if word or phrase exists
    Enum.each(tokens, fn token -> 
      Brain.get_or_start token.phrase     
    end)

    if Enum.empty?(brain_cells) do
      String.starts_with?("hello world", "hello")
      Logger.warning("⚠️ No usable BrainCells for: #{inspect(input)}")
      {:error, :not_found}
    else
      {:ok, IntentResolver.resolve_intent(brain_cells)}
    end
  end


def resolve_and_classify(sentence) do
  semantic =
    %SemanticInput{sentence: sentence, source: :user}
    |> Tokenizer.tokenize()
    |> POSEngine.tag()
    |> Brain.link_cells()
    |> IntentClassifier.classify_tokens()
    |> MoodCore.attach_mood()
    |> ResponsePlanner.analyze()

  {:ok, %{semantic | intent: "unknown", keyword: nil, confidence: 0.0}}

end

  # Token → attach BrainCell if found
  def update_token_with_cell(%Token{phrase: word} = token) do
    case Brain.get_all(word.phrase) do
      %BrainCell{} = cell ->
        Brain.ensure_running(cell)
        %{token | cell: cell, pos: cell.pos, keyword: cell.word}

      nil ->
        Logger.warning("⚠️ No BrainCell found for #{inspect(word)}")
        token
    end
  end

  def activate_cells(token) do
    Brain.get_all(token.phrase)
    |> case do
      cells -> 
        Enum.each(cells, fn cell -> 
          Brain.ensure_started(cell)
        end)
        token
      _ -> token
    end
  end

  # Unused fallback enrichment (optional to keep or remove)
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
end

