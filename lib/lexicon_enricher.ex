defmodule LexiconEnricher do
  alias LexiconClient
  alias BrainCell
  alias Core.DB

  @doc """
  Enriches a word by fetching its meanings from the online dictionary,
  building BrainCell structs, and storing them in the Brain.
  Returns :ok on success or {:error, reason}.
  """
  def enrich(word) when is_binary(word) do
    with {:ok, %{status: 200, body: [%{"word" => w, "meanings" => meanings} | _]}} <-
           LexiconClient.fetch_word(word),
         cells when is_list(cells) <- build_cells(w, meanings) do
    Enum.each(cells, fn cell ->
IO.inspect cell
  case DB.insert(cell) do
    {:ok, _} -> :ok
    {:error, changeset} ->
      IO.puts("⚠️ Failed to insert cell: #{cell.id}")
      IO.inspect(changeset.errors)
  end
end)
  
    ## bookmarkIO.inspect Enum.map(cells, &DB.get(&1.id)), label: "✅ DB.get/1 after put"

      :ok
    else
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unexpected_format}
    end
  end

  defp build_cells(word, meanings) do
    Enum.flat_map(meanings, fn %{"partOfSpeech" => pos_str, "definitions" => defs} ->
      pos = normalize_pos(pos_str)

      Enum.with_index(defs, 1)
      |> Enum.map(fn {%{"definition" => defn} = defmap, idx} ->
        %BCell{
          id: "#{word}|#{pos}|#{idx}",
          word: word,
          pos: pos,
          definition: defn || "",
          example: defmap["example"] || "",
          synonyms: defmap["synonyms"] || [],
          antonyms: defmap["antonyms"] || [],
          type: nil,
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

  defp normalize_pos("noun"), do: :noun
  defp normalize_pos("verb"), do: :verb
  defp normalize_pos("adjective"), do: :adjective
  defp normalize_pos("adverb"), do: :adverb
  defp normalize_pos("interjection"), do: :interjection
  defp normalize_pos("conjunction"), do: :conjunction
  defp normalize_pos("preposition"), do: :preposition
  defp normalize_pos(_), do: :unknown
end
