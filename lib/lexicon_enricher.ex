defmodule LexiconEnricher do
  alias LexiconClient
  alias BrainCell

  @doc """
  Fetches a word from the online dictionary and returns a list of BrainCell structs,
  one per meaning + POS.
  """
  def enrich(word) when is_binary(word) do
    case LexiconClient.fetch_word(word) do
      {:ok, %{status: 200, body: [%{"word" => w, "meanings" => meanings} | _]}} ->
        cells =
          meanings
          |> Enum.flat_map(fn %{"partOfSpeech" => pos_str, "definitions" => defs} ->
            pos = normalize_pos(pos_str)

            Enum.with_index(defs, 1)
            |> Enum.map(fn {defn, idx} ->
              %BrainCell{
                id: "#{w}|#{pos}|#{idx}",
                word: w,
                pos: pos,
                definition: defn["definition"] || "",
                example: defn["example"] || "",
                synonyms: defn["synonyms"] || [],
                antonyms: defn["antonyms"] || [],
                type: nil,
                activation: 0.0,
                serotonin: 1.0,
                dopamine: 1.0,
                connections: [],
                position: {0.0, 0.0, 0.0},
                status: :active,
                last_dose_at: nil,
                last_substance: nil
              }
            end)
          end)

        {:ok, cells}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
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

