defmodule LexiconEnricher do
  @moduledoc """
  Enriches a word by fetching its meanings from the internal lexicon or online dictionary,
  building BrainCell structs, and storing them in the Brain.

  Returns {:ok, cells} on success or {:error, reason}.
  """

  alias LexiconClient
  alias BrainCell
  alias Core.DB

  @spec enrich(String.t()) :: {:ok, [BrainCell.t()]} | {:error, term()}
  def enrich(word) when is_binary(word) do
    word_down = String.downcase(word)
    IO.inspect(word_down, label: "LexiconEnricher.enrich called with")

    case Map.get(@internal_lexicon, word_down) do
      nil -> fetch_from_api(word_down)

      internal_meanings when is_list(internal_meanings) ->
        cells = build_cells(word_down, internal_meanings)
        Enum.each(cells, &insert_cell/1)
        {:ok, cells}
    end
  end

  def enrich(_), do: {:error, :invalid_word}

  defp fetch_from_api(word) do
    with {:ok, %{status: 200, body: [%{"word" => w, "meanings" => meanings} | _]}} <- LexiconClient.fetch_word(word),
         cells when is_list(cells) <- build_cells(w, meanings) do
      Enum.each(cells, &insert_cell/1)
      IO.puts("🧠 Enriched new word from API: #{word}")
      {:ok, cells}
    else
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unexpected_format}
    end
  end

  defp insert_cell(cell) do
    opts = [on_conflict: :nothing, conflict_target: :id]

    case DB.insert(cell, opts) do
      {:ok, _} -> :ok
      {:error, changeset} ->
        IO.puts("⚠️ Failed to insert cell: #{cell.id}")
        IO.inspect(changeset.errors)
    end
  end

  defp build_cells(word, meanings) do
    Enum.flat_map(meanings, fn %{"partOfSpeech" => pos, "definitions" => defs} ->
      Enum.with_index(defs, 1)
      |> Enum.map(fn {%{"definition" => defn} = defmap, idx} ->
        atoms = semantic_atoms(defn || "", defmap["synonyms"] || [])

        %BrainCell{
          id: "#{word}|#{pos}|#{idx}",
          word: word,
          pos: pos,
          definition: defn || "",
          example: defmap["example"] || "",
          synonyms: defmap["synonyms"] || [],
          antonyms: defmap["antonyms"] || [],
          semantic_atoms: atoms,
          type: nil,
          function: nil,
          activation: 0.0,
          serotonin: 1.0,
          dopamine: 1.0,
          connections: [],
          position: [0.0, 0.0, 0.0],
          status: :active,
          last_dose_at: nil,
          last_substance: nil
        }
      end)
    end)
  end

  defp semantic_atoms(definition, synonyms) do
    defn_tokens =
      Core.Tokenizer.tokenize(definition)
      |> Enum.map(& &1.word)

    (defn_tokens ++ synonyms)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
    |> Enum.reject(&too_short_or_common?/1)
  end

  defp too_short_or_common?(word) do
    String.length(word) <= 2 or word in ~w[to and the or of a an is in on at by for with from]
  end

  @internal_lexicon %{
    # Be verbs
    "be" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "exist", "example" => "To be or not to be", "synonyms" => ["exist", "occur"], "antonyms" => []}]}],
    "am" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "first person singular present of be", "example" => "I am happy", "synonyms" => ["exist"], "antonyms" => []}]}],
    "is" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "third person singular present of be", "example" => "She is here", "synonyms" => ["exists"], "antonyms" => []}]}],
    "are" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "second person singular and plural present of be", "example" => "You are welcome", "synonyms" => ["exist"], "antonyms" => []}]}],
    "was" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "first and third person singular past of be", "example" => "He was late", "synonyms" => [], "antonyms" => []}]}],
    "were" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "second person singular and plural past of be", "example" => "They were here", "synonyms" => [], "antonyms" => []}]}],

    # Have verbs
    "have" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "possess, own, or hold", "example" => "I have a book", "synonyms" => ["own", "possess"], "antonyms" => []}]}],
    "has" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "third person singular present of have", "example" => "She has a car", "synonyms" => ["owns"], "antonyms" => []}]}],
    "had" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "past tense of have", "example" => "He had a dog", "synonyms" => ["owned"], "antonyms" => []}]}],

    # Do verbs
    "do" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "perform an action", "example" => "I do my homework", "synonyms" => ["perform", "execute"], "antonyms" => []}]}],
    "does" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "third person singular present of do", "example" => "She does the dishes", "synonyms" => ["performs"], "antonyms" => []}]}],
    "did" => [%{"partOfSpeech" => "aux", "definitions" => [%{"definition" => "past tense of do", "example" => "They did the work", "synonyms" => ["performed"], "antonyms" => []}]}],

    # Modal verbs
    "can" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express ability or possibility", "example" => "I can swim", "synonyms" => ["be able to"], "antonyms" => []}]}],
    "could" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "past of can, express possibility or ability", "example" => "She could come", "synonyms" => [], "antonyms" => []}]}],
    "may" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express possibility or permission", "example" => "You may leave", "synonyms" => [], "antonyms" => []}]}],
    "might" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express possibility", "example" => "It might rain", "synonyms" => [], "antonyms" => []}]}],
    "must" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express necessity or obligation", "example" => "You must stop", "synonyms" => [], "antonyms" => []}]}],
    "shall" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express future intent or obligation", "example" => "I shall return", "synonyms" => [], "antonyms" => []}]}],
    "should" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express advice or expectation", "example" => "You should eat", "synonyms" => [], "antonyms" => []}]}],
    "will" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express future intent or willingness", "example" => "I will go", "synonyms" => [], "antonyms" => []}]}],
    "would" => [%{"partOfSpeech" => "modal", "definitions" => [%{"definition" => "express conditional intent", "example" => "I would help", "synonyms" => [], "antonyms" => []}]}]
  }
end

