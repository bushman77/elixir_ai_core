defmodule Core do
  @moduledoc """
  Core reasoning and decision-making functions,
  including sentence interpretation, lexicon enrichment, and brain memory.
  """

  alias Brain
  alias BrainCell

  # --- Inference Model Interface ---

  @spec dummy_model(map()) :: {:ok, atom()}
  def dummy_model(%{input: "Hello"}), do: {:ok, :greeting}
  def dummy_model(_), do: {:ok, :unknown}

  @spec load_model((map() -> {:ok, atom()})) :: :ok
  def load_model(model_fun) do
    GenServer.call(__MODULE__, {:load_model, model_fun})
  end

  @spec infer((map() -> any()) | nil, map()) :: {:ok, any()} | {:error, atom()}
  def infer(nil, _input), do: {:error, :no_model_loaded}
  def infer(model_fun, %{} = input) when is_function(model_fun, 1), do: model_fun.(input)
  def infer(_model, _invalid_input), do: {:error, :invalid_input}

  # --- Sentence Analysis ---

  @spec interpret(String.t()) :: map()
  def interpret(sentence) when is_binary(sentence) do
    tokens = Tokenizer.tokenize(sentence)
    tagged = POSTagger.tag(tokens)

    %{
      input: sentence,
      tokens: tokens,
      tagged: tagged
    }
  end

  # --- Lexicon Enrichment ---

  @spec extract_definitions(map()) :: [
          %{
            word: String.t(),
            pos: atom(),
            definition: String.t(),
            example: String.t() | nil,
            synonyms: [String.t()],
            antonyms: [String.t()]
          }
        ]
  def extract_definitions(%{"word" => word, "meanings" => meanings}) do
    Enum.flat_map(meanings, fn %{"partOfSpeech" => pos_str, "definitions" => defs} ->
      pos = normalize_pos(pos_str)

      Enum.map(defs, fn def ->
        %{
          word: word,
          pos: pos,
          definition: def["definition"],
          example: def["example"],
          synonyms: def["synonyms"] || [],
          antonyms: def["antonyms"] || []
        }
      end)
    end)
  end

  def extract_definitions(_), do: []

  @spec to_brain_cells([map()]) :: [BrainCell.t()]
  def to_brain_cells(definitions) when is_list(definitions) do
    Enum.with_index(definitions, 1)
    |> Enum.map(fn {entry, index} ->
      %BCell{
        id: "#{entry.word}|#{entry.pos}|#{index}",
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
        position: {0.0, 0.0, 0.0},
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
      Enum.map(cells, fn %BCell{id: id} = cell ->
        case Registry.lookup(BrainCell.Registry, id) do
          [] ->
            case BrainCell.start_link(cell) do
              {:ok, _pid} ->
                IO.inspect(cell)
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

  # --- Recursive Learning & Intent Detection ---

  @doc """
  Recursively enriches and memorizes all unknown words in the input,
  then classifies the sentence intent.
  Silent on success, returns error message if enrichment fails.
  """
  @spec resolve_and_classify(String.t()) :: {:answer, map()} | {:error, :dictionary_missing}
  def resolve_and_classify(input), do: resolve_and_classify(input, 0)

  defp resolve_and_classify(_input, 5), do: {:error, :dictionary_missing}

  defp resolve_and_classify(input, depth) do
    tokens = Tokenizer.tokenize(input)
    unknowns = for %{word: word, pos: [:unknown]} <- tokens, do: word

    if unknowns == [] do
      {:answer, Core.POS.classify_input(tokens)}
    else
      results =
        Enum.map(unknowns, fn word ->
          with {:ok, map} <- LexiconEnricher.enrich(word),
               {:ok, _ids} <- memorize(map) do
            :ok
          else
            _ -> {:error, word}
          end
        end)

      if Enum.any?(results, &match?({:error, _}, &1)) do
        {:error, :dictionary_missing}
      else
        resolve_and_classify(input, depth + 1)
      end
    end
  end

  @doc "Clamps a float value between min and max."
  def clamp(val), do: clamp(val, 0.0, 2.0)
  @spec clamp(float(), float(), float()) :: float()
  def clamp(val, min, max) when is_float(val) and is_float(min) and is_float(max) do
    val |> max(min) |> min(max)
  end

  # --- Helpers ---

  defp normalize_pos("noun"), do: :noun
  defp normalize_pos("verb"), do: :verb
  defp normalize_pos("adjective"), do: :adjective
  defp normalize_pos("adverb"), do: :adverb
  defp normalize_pos("interjection"), do: :interjection
  defp normalize_pos(_), do: :unknown
end
