defmodule LexiconEnricher do
  alias LexiconClient

  @doc """
  Fetches word definitions from the online dictionary API,
  parses them, and inserts them into the DETS lexicon table.
  """
  def enrich(word) do
    case LexiconClient.fetch_word(word) do
      {:ok, %{status: 200, body: [entry | _]}} ->
        synsets = parse_meanings(entry["meanings"])
        # synsets
        # |> List.first
        entry
        |> IO.inspect()

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_meanings(meanings) do
    Enum.map(meanings, fn %{"partOfSpeech" => pos, "definitions" => defs} ->
      lemma = "#{abbreviate(pos)}.#{pos}"

      %{
        lemma: lemma,
        synsets:
          Enum.with_index(defs)
          |> Enum.map(fn {defn, i} ->
            gloss = defn["definition"]
            ex = Map.get(defn, "example", nil)

            %{
              id: "#{abbreviate(pos)}#{pad_index(i)}",
              pos: abbreviate(pos),
              gloss: gloss,
              examples: if(ex, do: [ex], else: []),
              relations: %{}
            }
          end)
      }
    end)
  end

  defp abbreviate("noun"), do: "n"
  defp abbreviate("verb"), do: "v"
  defp abbreviate("adjective"), do: "a"
  defp abbreviate("adverb"), do: "r"
  defp abbreviate("conjunction"), do: "c"
  defp abbreviate("interjection"), do: "i"
  defp abbreviate(_), do: "u"

  defp pad_index(i), do: String.pad_leading(Integer.to_string(i + 1), 6, "0")
end
