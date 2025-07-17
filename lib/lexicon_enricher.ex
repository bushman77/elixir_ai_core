defmodule LexiconEnricher do
  @moduledoc """
  Enriches a word by checking the database first, then fetching from the online dictionary if not found.
  Builds BrainCell structs and inserts them into the Brain.
  Logs only when enrichment occurs via the API.
  """

  alias LexiconClient
  alias BrainCell
  alias Core.DB

  @spec enrich(String.t()) :: {:ok, [BrainCell.t()] | :already_known} | {:error, term()}
  def enrich(word) when is_binary(word) do
    word_down = String.downcase(word)
    IO.inspect(word_down, label: "LexiconEnricher.enrich called with")

    # 1. Check database
    if DB.has_word?(word_down) do
      {:ok, :already_known}
    else
      # 2. Fallback to external fetch
      fetch_from_api(word_down)
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

defp semantic_atoms(_definition, synonyms) do
  synonyms
  |> Enum.map(&String.downcase/1)
  |> Enum.uniq()
  |> Enum.reject(&too_short_or_common?/1)
end

  defp too_short_or_common?(word) do
    String.length(word) <= 2 or word in ~w[to and the or of a an is in on at by for with from]
  end
end

