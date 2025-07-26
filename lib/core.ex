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
  alias Core.{Tokenizer, IntentMatrix, DB}
  import Core.POS, only: [normalize_pos: 1]

  # ---------------------------------------------------------------------
  # 🧠 BrainCell Construction & Memory
  # ---------------------------------------------------------------------

  @spec extract_definitions(map()) :: [map()]
  def extract_definitions(%{"word" => word, "meanings" => meanings}) when is_list(meanings) do
    Enum.flat_map(meanings, fn %{"partOfSpeech" => pos_str, "definitions" => defs} ->
      pos = normalize_pos(pos_str)

      Enum.map(defs || [], fn def ->
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
      Enum.map(cells, fn %BrainCell{id: id} = cell ->
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
      end)

    case Enum.filter(results, &match?({:error, _}, &1)) do
      [] -> {:ok, Enum.map(results, fn {:ok, id} -> id end)}
      errors -> {:error, errors}
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

    case extract_unknown_words(tokens) do
      [] ->
        {:answer,
         Map.merge(IntentMatrix.classify(tokens), %{
           tokens: tokens,
           keyword: extract_keyword(tokens)
         })}

      unknowns ->
        case handle_unknowns(unknowns) do
          :ok -> resolve_and_classify(input, depth + 1)
          _ -> {:error, :dictionary_missing}
        end
    end
  end

  defp extract_unknown_words(tokens) do
    tokens
    |> Enum.filter(&Enum.member?(&1.pos, :unknown))
    |> Enum.map(& &1.word)
    |> Enum.uniq()
  end

  defp handle_unknowns(words) do
    results =
      Enum.map(words, fn word ->
        with {:ok, cells} <- LexiconEnricher.enrich(word),
             {:ok, _} <- memorize(cells) do
          IO.inspect(cells, label: "🧬 Enriched brain cells for #{word}")
          :ok
        else
          _ -> {:error, word}
        end
      end)

    if Enum.any?(results, &match?({:error, _}, &1)), do: {:error, :fail}, else: :ok
  end

  defp extract_keyword([%{word: w} | _]), do: w
  defp extract_keyword(_), do: "that"

  # ---------------------------------------------------------------------
  # 🛠️ Activation & Attention Helpers
  # ---------------------------------------------------------------------

  @spec clamp(float(), float(), float()) :: float()
  def clamp(val), do: clamp(val, 0.0, 2.0)

  def clamp(val, min, max) when is_float(val), do: val |> max(min) |> min(max)

  defp debug_log(value) do
    if Application.get_env(:elixir_ai_core, :debug, false) do
      IO.inspect(value, label: "DEBUG")
    end
  end

  @doc """
  Ensures attention on tokens: for any phrase not already in attention, start its cell.
  """
  def set_attention(tokens) when is_list(tokens) do
    state = Brain.get_state()
    active_ids = state.attention

    Enum.each(tokens, fn %{phrase: phrase} ->
      unless phrase_in_attention?(phrase, active_ids), do: ensure_cell_started(phrase)
    end)
  end

  defp phrase_in_attention?(phrase, active_ids) do
    Enum.any?(active_ids, fn
      %BrainCell{word: w} -> w == phrase
      id when is_binary(id) -> id == phrase
      _ -> false
    end)
  end

  @doc """
  Ensures a brain cell for the given phrase is active,
  enriching and starting it if necessary.
  """
  @spec ensure_cell_started(String.t()) :: :ok | {:error, any()}
  def ensure_cell_started(phrase) when is_binary(phrase) do
    case Registry.lookup(Core.Registry, phrase) do
      [_] -> :ok
      [] -> maybe_start_cell(phrase)
    end
  end

  defp maybe_start_cell(phrase) do
    cond do
      DB.cell_exists?(phrase) ->
        Brain.get_or_start(phrase)

      true ->
case LexiconEnricher.enrich(phrase) do
  {:ok, [%BrainCell{} | _] = cells} ->
    Enum.each(cells, &DB.insert_cell!/1)
    Enum.each(cells, fn cell -> Brain.get_or_start(cell.word) end)
    :ok

  {:ok, %BrainCell{} = cell} ->  # fallback for single structs just in case
    DB.insert_cell!(cell)
    Brain.get_or_start(cell.word)

  {:ok, :already_known} ->
    Brain.get_or_start(phrase)

  :already_known ->
    Brain.get_or_start(phrase)

  {:error, :not_found} ->
    try_fragments(phrase)

  {:error, reason} ->
    {:error, reason}
end
        
    end
  end

  defp try_fragments(phrase) do
    phrase
    |> Tokenizer.fragment_phrases()
    |> Enum.find_value(fn frag ->
      case ensure_cell_started(frag) do
        :ok -> :ok
        _ -> nil
      end
    end) || {:error, :not_found}
  end
end

