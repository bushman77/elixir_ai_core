defmodule Core do
  require Logger

  alias Core.{Tokenizer, IntentResolver, Token, DB}
  alias LexiconEnricher

  @max_retry 2

  # Entry point for raw string input with retries
  def resolve_input(input, retry_count \\ 0)

  def resolve_input(input, retry_count) when retry_count < @max_retry do
    tokens =
      input
      |> Tokenizer.resolve_phrases()
      |> Enum.map(&%Token{phrase: &1})

    phrases = Enum.map(tokens, & &1.phrase)

    case ensure_cells_started(phrases) do
      {:ok, brain_cells} ->
        Logger.debug("🧠 BrainCells activated: #{length(brain_cells)}")
        {:ok, IntentResolver.resolve_intent(brain_cells)}

      {:error, :not_found} ->
        Logger.warning("⚠️ Enrichment failed for '#{input}': :not_found")
        resolve_input(input, retry_count + 1)
    end
  end

  def resolve_input(_input, _retry_count), do: {:error, :max_retries_exceeded}

  # Entry point for list of phrases or pre-enriched input
  def resolve_input(input, opts) when is_list(input) and is_list(opts) do
    case ensure_cells_started(input) do
      {:ok, cells} ->
        classify_and_plan(cells, opts)

      {:error, reason} ->
        IO.warn("⚠️ Could not resolve input: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def resolve_and_classify(input) do
    case resolve_input(input) do
      {:ok, intent_result} -> intent_result
      {:error, _} -> %{intent: :unknown, confidence: 0.0, reason: :unresolved}
    end
  end

  # Ensures cells for each phrase are started and returns the list
  def ensure_cells_started(phrases) do
    cells =
      phrases
      |> Enum.flat_map(&load_or_enrich_cells/1)

    Enum.each(cells, fn cell -> Brain.ensure_started(cell) end)

    case cells do
      [] -> {:error, :not_found}
      _ -> {:ok, cells}
    end
  end

  # Attempts to load existing cells, or enriches if not present
  defp load_or_enrich_cells(phrase) do
    case Brain.get_all(phrase) do
      [] ->
        case LexiconEnricher.enrich(phrase) do
          {:ok, cells} ->
IO.inspect cells
            store_cells(cells)
            cells

          {:error, reason} ->
            Logger.warn("⚠️ Enrichment failed for '#{phrase.phrase}': #{inspect(reason)}")
            []
        end

      existing -> existing
    end
  end

  # Stores cells to DB and brain registry
  defp store_cells(cells) do
    Enum.each(cells, fn cell ->
      normalized = normalize_cell(cell)

      unless DB.cell_exists?(normalized.id) do
        DB.insert_cell!(normalized)
      end

      Brain.store(normalized)
    end)
  end

  # Normalize any loaded or enriched BrainCell struct
  defp normalize_cell(%BrainCell{} = cell) do
    cell
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__])
    |> then(&struct(BrainCell, &1))
  end

  # Placeholder for downstream planner
  defp classify_and_plan(cells, _opts) do
    %{tokens: cells, intent: :placeholder}
  end
end

