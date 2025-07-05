defmodule Core do
  @moduledoc """
  Core reasoning and decision-making functions,
  including sentence interpretation, lexicon enrichment, and brain memory.
  """

  @spec dummy_model(map()) :: {:ok, atom()}
  def dummy_model(%{input: "Hello"}), do: {:ok, :greeting}
  def dummy_model(_), do: {:ok, :unknown}

  @spec load_model((map() -> {:ok, atom()})) :: :ok
  def load_model(model_fun) do
    GenServer.call(__MODULE__, {:load_model, model_fun})
  end

  @doc """
  Handles inference requests based on input.
  """
  @spec infer((map() -> any()) | nil, map()) :: {:ok, any()} | {:error, atom()}
  def infer(nil, _input), do: {:error, :no_model_loaded}
  def infer(model_fun, %{} = input) when is_function(model_fun, 1), do: model_fun.(input)
  def infer(_model, _invalid_input), do: {:error, :invalid_input}

  @doc """
  Clamp a float between 0.0 and 2.0 by default.
  """
  def clamp(val), do: clamp(val, 0.0, 2.0)

  @spec clamp(float(), float(), float()) :: float()
  def clamp(val, min, max) when is_float(val) and is_float(min) and is_float(max) do
    val |> max(min) |> min(max)
  end

  @doc """
  Interpret a sentence:
  - Tokenizes input
  - Tags parts of speech
  - Returns POS-tagged token list
  """
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

  @doc """
  Extracts a simplified list of definitions from an external lexicon map
  (fetched using Tesla scraper).
  """
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

  @doc """
  Converts lexicon definitions into BrainCell structs.
  """
  @spec to_brain_cells([map()]) :: [BrainCell.t()]
  def to_brain_cells(definitions) when is_list(definitions) do
    Enum.with_index(definitions, 1)
    |> Enum.map(fn {%{
                      word: word,
                      pos: pos,
                      definition: defn,
                      example: example,
                      synonyms: syns,
                      antonyms: ants
                    }, index} ->
      %BrainCell{
        id: "#{word}|#{pos}|#{index}",
        word: word,
        pos: pos,
        definition: defn,
        example: example,
        synonyms: syns || [],
        antonyms: ants || [],
        activation: 0.0,
        serotonin: 1.0,
        dopamine: 1.0,
        connections: [],
        position: {0, 0},
        last_dose_at: nil,
        last_substance: nil
      }
    end)
  end

  @doc """
  Memorizes a word by extracting its definitions,
  creating BrainCells for each, storing them in the brain,
  and activating their GenServers.
  """
  @spec memorize(map()) :: {:ok, [String.t()]} | {:error, atom()}
  def memorize(%{"word" => _word} = lexicon_map) do
    lexicon_map
    |> extract_definitions()
    |> to_brain_cells()
    |> Enum.map(fn cell ->
      :ok = Brain.put(cell)
      BrainSupervisor.start_child(cell)
      cell.id
    end)
    |> then(&{:ok, &1})
  end

  def memorize(_), do: {:error, :invalid_format}

  defp normalize_pos("noun"), do: :noun
  defp normalize_pos("verb"), do: :verb
  defp normalize_pos("adjective"), do: :adjective
  defp normalize_pos("adverb"), do: :adverb
  defp normalize_pos("interjection"), do: :interjection
  defp normalize_pos(_), do: :unknown
end
