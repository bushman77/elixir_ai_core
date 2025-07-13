defmodule LexiconEnricher do
  @moduledoc """
  Enriches a word by fetching its meanings from the online dictionary,
  building BrainCell structs, and storing them in the Brain.

  Returns `:ok` on success or `{:error, reason}`.
  """

  alias LexiconClient
  alias BrainCell
  alias Core.DB

  @spec enrich(String.t()) :: :ok | {:error, term()}
  def enrich(word) when is_binary(word) do
    with {:ok, %{status: 200, body: [%{"word" => w, "meanings" => meanings} | _]}} <-
           LexiconClient.fetch_word(word),
         cells when is_list(cells) <- build_cells(w, meanings) do
      Enum.each(cells, &insert_cell/1)
      :ok
    else
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unexpected_format}
    end
  end

  defp insert_cell(cell) do
    case DB.insert(cell) do
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
        %BrainCell{
          id: "#{word}|#{pos}|#{idx}",
          word: word,
          pos: pos,
          definition: defn || "",
          example: defmap["example"] || "",
          synonyms: defmap["synonyms"] || [],
          antonyms: defmap["antonyms"] || [],
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
end

