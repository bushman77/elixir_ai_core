defmodule LexiconEnricher do
  @moduledoc """
  Pure enrichment module. Fetches word data from a remote API and builds BrainCell structs.
  No DB interaction occurs here — Brain owns persistence and process lifecycle.
  """

  alias LexiconClient
  alias BrainCell

  @spec enrich(String.t()) :: {:ok, [BrainCell.t()]} | {:error, atom()}
  def enrich(word) when is_binary(word), do: fetch_from_api(String.downcase(word))
  def enrich(_), do: {:error, :invalid_word}

  @spec update(String.t()) :: {:ok, [BrainCell.t()]} | {:error, atom()}
  def update(word), do: enrich(word)

  defp fetch_from_api(word) do
    with {:ok, %{status: 200, body: [%{"word" => w, "meanings" => meanings} | _]}} <- LexiconClient.fetch_word(word),
         cells when is_list(cells) <- build_cells(w, meanings) do
      {:ok, cells}   # emit structs only
    else
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unexpected_format}
    end
  end

  # Build a list of %BrainCell{} templates (no DB fields like token_id here)
  defp build_cells(word, meanings) do
    word = norm(word)

    meanings
    |> List.wrap()
    |> Enum.flat_map(fn meaning ->
      pos      = get_in(meaning, ["partOfSpeech"]) || get_in(meaning, [:partOfSpeech]) || "unknown"
      pos_syns = norm_list(List.wrap(meaning["synonyms"] || meaning[:synonyms]))
      defs     = List.wrap(meaning["definitions"] || meaning[:definitions])

      defs
      |> Enum.with_index(1)
      |> Enum.map(fn {defmap, idx} ->
        defn    = norm(defmap["definition"] || defmap[:definition] || "")
        example = norm(defmap["example"]    || defmap[:example]    || "")
        d_syns  = norm_list(List.wrap(defmap["synonyms"]  || defmap[:synonyms]))
        ants    = norm_list(List.wrap(defmap["antonyms"] || defmap[:antonyms]))
        syns    = norm_list(pos_syns ++ d_syns, 128)
        atoms   = semantic_atoms(defn, syns)

        %BrainCell{
          id: "#{word}|#{pos}|#{idx}",
          word: word,
          pos: pos,
          definition: defn,
          example: example,
          synonyms: syns,
          antonyms: ants,
          semantic_atoms: atoms,
          type: nil,
          function: nil,
          activation: 0.0,
          modulated_activation: 0.0,
          dopamine: 1.0,
          serotonin: 1.0,
          connections: [],                 # {:array, :map} in schema
          position: [0.0, 0.0, 0.0],
          status: :active
          # NOTE: no :token_id here; Brain.ensure_braincell/3 sets it
        }
      end)
    end)
  end

  # --- helpers ---

  defp norm(nil), do: ""
  defp norm(s) when is_binary(s), do: s |> String.trim() |> :unicode.characters_to_nfc_binary()
  defp norm(s), do: to_string(s) |> norm()

  defp norm_list(list, cap \\ 64) do
    list
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&norm/1)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == "" or String.length(&1) <= 2))
    |> Enum.take(cap)
  end

  defp semantic_atoms(_definition, synonyms) do
    synonyms
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
    |> Enum.reject(&too_short_or_common?/1)
  end

  defp too_short_or_common?(w),
    do: String.length(w) <= 2 or w in ~w[to and the or of a an is in on at by for with from]
end

