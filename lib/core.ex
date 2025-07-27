defmodule Core do
  @moduledoc """
  Central coordination module for the neuro-symbolic pipeline.
  Handles tokenization, enrichment, intent resolution, and feedback loops.
  """

  alias Core.{Tokenizer, IntentResolver, DB}
  alias LexiconEnricher
  alias Brain
  alias Core.Token

  @max_retry 5

  # === ENTRY POINT ===
  @doc """
  Resolves an input string by:
    - Tokenizing into n-gram phrases
    - Enriching with BrainCell info if known
    - Auto-enriching unknown tokens via Lexicon
    - Recursively resolving up to #{@max_retry} tries

  Returns:
    {:answer, %{intent, keyword, confidence, tokens}}
    or
    {:error, :dictionary_missing}
  """
  @spec resolve_and_classify(String.t()) :: {:answer, map()} | {:error, :dictionary_missing}
  def resolve_and_classify(input), do: resolve_and_classify(input, 0)

  defp resolve_and_classify(_input, @max_retry), do: {:error, :dictionary_missing}

defp resolve_and_classify(input, depth) when depth < @max_retry do
  tokens = input |> tokenize() |> enrich_tokens()

  unknowns = find_unknown_tokens(tokens)

  case unknowns do
    [] ->
      intent_result = IntentResolver.resolve_intent(tokens)
      {:answer, Map.put(intent_result, :tokens, tokens)}

    _unknowns ->
      IO.puts("🔍 Retry #{depth + 1}: Still unknown tokens: #{inspect(unknowns)}")

      with :ok <- enrich_unknowns(unknowns) do
        resolve_and_classify(input, depth + 1)
      else
        _ -> {:error, :dictionary_missing}
      end
  end
end

defp resolve_and_classify(_input, @max_retry) do
  IO.puts("❌ Max retries reached. Could not resolve all tokens.")
  {:error, :dictionary_missing}
end

  # === TOKENIZATION ===

  defp tokenize(input) do
    Tokenizer.resolve_phrases(input)
  end

  # === ENRICHMENT ===

  defp enrich_tokens(tokens) do
    Enum.map(tokens, &ensure_token_enriched/1)
  end

  defp ensure_token_enriched(%Token{phrase: phrase} = token) do
    case Brain.get(phrase) do
      nil -> token
      cell -> Token.update_from_cell(token, cell)
    end
  end

  defp find_unknown_tokens(tokens) do
    tokens
    |> Enum.filter(fn
      %Token{pos: nil} -> true
      %Token{pos: :unknown} -> true
      %Token{pos: "unknown"} -> true
      _ -> false
    end)
    |> Enum.map(& &1.phrase)
    |> Enum.uniq()
  end

  defp enrich_unknowns(phrases) do
    results =
      Enum.map(phrases, fn phrase ->
        with {:ok, cells} <- LexiconEnricher.enrich(phrase),
             {:ok, _} <- memorize(cells) do
          IO.inspect(cells, label: "🧬 Enriched brain cells for #{phrase}")
          :ok
        else
          _ -> {:error, phrase}
        end
      end)

    if Enum.any?(results, &match?({:error, _}, &1)), do: {:error, :fail}, else: :ok
  end

  # === MEMORY PERSISTENCE ===

  @spec memorize([BrainCell.t()]) :: {:ok, [BrainCell.t()]} | {:error, any()}
  defp memorize(cells) when is_list(cells) do
    results =
      Enum.map(cells, fn cell ->
        if DB.cell_exists?(cell.id) do
          :ok
        else
          cell
          |> normalize_cell()
          |> DB.insert_cell!()
          |> then(fn _ -> :ok end)
        end
      end)

    if Enum.all?(results, &(&1 == :ok)), do: {:ok, cells}, else: {:error, :db_failure}
  end

  defp normalize_cell(%BrainCell{word: word} = cell) do
    %BrainCell{cell | word: String.downcase(word)}
  end
end

