defmodule WordNet do
  @moduledoc """
  Accesses WordNet data from the DETS lemma_index table.

  Supports lookup by word and POS tag (e.g., :verb, :noun),
  as well as retrieving all synsets across parts of speech.
  """

  @table :lemma_index
  @path ~c"priv/wordnet_lemma_index.dets"

  # Public API

  def lookup_all_raw(word) when is_binary(word) do
    open()

    :dets.foldl(
      fn {key, val}, acc ->
        if String.ends_with?(to_string(key), "." <> word) do
          [{key, val} | acc]
        else
          acc
        end
      end,
      [],
      @table
    )
  end

  def lookup(word, pos) when is_binary(word) and is_atom(pos) do
    open()

    key = "#{to_pos_code(pos)}.#{word}"

    case :dets.lookup(@table, key) do
      [{^key, %{synsets: synsets}}] ->
        case Enum.find(synsets, fn %{"pos" => p} -> normalize_pos(p) == pos end) do
          nil ->
            fallback_struct(key, pos)

          synset ->
            %{
              definition: Map.get(synset, "gloss", ""),
              synonyms: Map.get(synset, "words", []) || [],
              examples: Map.get(synset, "examples", [])
            }
        end

      _ ->
        fallback_struct(key, pos)
    end
  end

  def lookup_all(word) when is_binary(word) do
    open()

    ["n", "v", "a", "r", "s"]
    |> Enum.map(&"#{&1}.#{word}")
    |> Enum.flat_map(fn key ->
      case :dets.lookup(@table, key) do
        [{_, %{synsets: synsets}}] -> synsets
        _ -> []
      end
    end)
  end

  def split_by_pos(synsets) when is_list(synsets) do
    Enum.group_by(synsets, fn %{"pos" => pos} -> normalize_pos(pos) end)
  end

  # Helpers

  defp fallback_struct(word_key, pos) do
    %{
      definition: "No definition found for #{word_key}/#{Atom.to_string(pos)}",
      synonyms: [],
      examples: []
    }
  end

  defp to_pos_code(:verb), do: "v"
  defp to_pos_code(:noun), do: "n"
  defp to_pos_code(:adjective), do: "a"
  defp to_pos_code(:adverb), do: "r"
  defp to_pos_code(_), do: "u"

  defp normalize_pos("v"), do: :verb
  defp normalize_pos("n"), do: :noun
  defp normalize_pos("a"), do: :adjective
  defp normalize_pos("s"), do: :adjective
  defp normalize_pos("r"), do: :adverb
  defp normalize_pos(_), do: :unknown

  defp open() do
    :dets.open_file(@table, file: @path)
  end
end
