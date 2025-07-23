defmodule Core do
  @moduledoc """
  Core reasoning and decision-making functions:
  - Sentence interpretation & POS tagging
  - Lexicon enrichment and memory (brain cells)
  - Recursive learning for unknown words
  - Intent classification and keyword extraction
  """

  alias Brain
  alias BrainCell
  alias LexiconEnricher
  alias Core.{Tokenizer, IntentMatrix, MultiwordMatcher}
  import Core.POS, only: [normalize_pos: 1]

  # ---------------------------------------------------------------------
  # 🧠 BrainCell Construction & Memory Management
  # ---------------------------------------------------------------------

  @spec extract_definitions(map()) :: [map()]
  def extract_definitions(%{"word" => word, "meanings" => meanings}) when is_list(meanings) do
    Enum.flat_map(meanings, fn %{"partOfSpeech" => pos_str, "definitions" => defs} ->
      pos = normalize_pos(pos_str)
      defs = defs || []

      Enum.map(defs, fn def ->
        %{
          word: word,
          pos: pos,
          definition: def["definition"] || "",
          example: def["example"],
          synonyms: def["synonyms"] || [],
          antonyms: def["antonyms"] || []
        }
      end)
    end)
  end

  def extract_definitions(_), do: []

  @spec to_brain_cells([map()]) :: [BrainCell.t()]
  def to_brain_cells(definitions) do
    Enum.with_index(definitions, 1)
    |> Enum.map(fn {entry, idx} ->
      %BrainCell{
        id: "#{entry.word}|#{entry.pos}|#{idx}",
        word: entry.word,
        pos: entry.pos,
        definition: entry.definition,
        example: entry.example,
        synonyms: entry.synonyms || [],
        antonyms: entry.antonyms || [],
        activation: 0.0,
        serotonin: 1.0,
        dopamine: 1.0,
        connections: [],
        position: [0.0, 0.0, 0.0],
        status: :active,
        last_dose_at: nil,
        last_substance: nil,
        type: nil
      }
    end)
  end

  @spec memorize([BrainCell.t()]) :: {:ok, [String.t()]} | {:error, list()}
  def memorize(cells) when is_list(cells) do
    results =
      Enum.map(cells, fn
        %BrainCell{id: id} = cell ->
          case Registry.lookup(Core.Registry, id) do
            [] ->
              case BrainCell.start_link(cell) do
                {:ok, _pid} ->
                  debug_log(cell)
                  Brain.put(cell)
                  {:ok, id}

                {:error, reason} ->
                  {:error, {id, reason}}
              end

            [_] ->
              {:ok, id}
          end

        {:error, reason} ->
          {:error, reason}

        unexpected ->
          {:error, {:unexpected_input, unexpected}}
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, Enum.map(results, fn {:ok, id} -> id end)}
    else
      {:error, errors}
    end
  end

  def memorize(_), do: {:error, :invalid_format}

  # ---------------------------------------------------------------------
  # 🔄 Recursive Lexicon Enrichment & Intent Detection
  # ---------------------------------------------------------------------

  @doc """
  Resolves unknown words by enriching dictionary, memorizing, then classifies intent.
  Stops after 5 attempts to avoid infinite recursion.
  """
  @spec resolve_and_classify(String.t()) :: {:answer, map()} | {:error, :dictionary_missing}
  def resolve_and_classify(input), do: resolve_and_classify(input, 0)

  defp resolve_and_classify(_input, 5), do: {:error, :dictionary_missing}

  defp resolve_and_classify(input, depth) do
    tokens = Tokenizer.tokenize(input)

    unknown_words =
      tokens
      |> Enum.filter(&Enum.member?(&1.pos, :unknown))
      |> Enum.map(& &1.word)
      |> Enum.uniq()

    case unknown_words do
      [] ->
        classification = IntentMatrix.classify(tokens)

        {:answer,
         Map.merge(classification, %{
           tokens: tokens,
           keyword: extract_keyword(tokens)
         })}

      unknowns ->
        results =
          Enum.map(unknowns, fn phrase_or_word ->
            with {:ok, cells} <- LexiconEnricher.enrich(phrase_or_word),
                 {:ok, _} <- memorize(cells) do
              IO.inspect(cells, label: "🧬 Enriched brain cells for #{phrase_or_word}")
              :ok
            else
              _ -> {:error, phrase_or_word}
            end
          end)

        if Enum.any?(results, &match?({:error, _}, &1)) do
          {:error, :dictionary_missing}
        else
          resolve_and_classify(input, depth + 1)
        end
    end
  end

  defp extract_keyword([%{word: word} | _]), do: word
  defp extract_keyword(_), do: "that"

  # ---------------------------------------------------------------------
  # 🛠️ Helpers
  # ---------------------------------------------------------------------

  @doc "Clamp a float value between min and max bounds."
  @spec clamp(float(), float(), float()) :: float()
  def clamp(val), do: clamp(val, 0.0, 2.0)

  def clamp(val, min, max) when is_float(val) and is_float(min) and is_float(max) do
    val |> max(min) |> min(max)
  end

  defp debug_log(value) do
    if Application.get_env(:elixir_ai_core, :debug, false) do
      IO.inspect(value, label: "DEBUG")
    else
      :ok
    end
  end
end

