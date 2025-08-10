defmodule Core.POS do
  @moduledoc """
  Handles part-of-speech tagging, multiword phrase merging, and POS normalization.
  """

  alias Core.Token
  alias Brain
  alias BrainCell

  @multiword_cutoff 4

  @doc """
  Enriches token structs with POS data from Brain.
  """
  def tag_token_structs(tokens) do
    Enum.map(tokens, fn %Token{text: word} = token ->
      case Brain.get(word) do
        %BrainCell{pos: pos} when is_list(pos) ->
          %{token | pos: normalize_all_pos(pos)}

        %BrainCell{pos: pos} ->
          %{token | pos: normalize_all_pos([pos])}

        _ ->
          %{token | pos: [:unknown]}
      end
    end)
  end

  @doc """
  Normalizes all POS tags to lowercase atoms.
  """
  def normalize_all_pos(pos_list) do
    pos_list
    |> Enum.map(&normalize_pos/1)
    |> Enum.uniq()
  end

  def normalize_pos(pos) when is_binary(pos) and pos != "" do
    pos |> String.downcase() |> String.to_atom()
  end
  def normalize_pos(pos) when is_atom(pos), do: pos
  def normalize_pos(_), do: :unknown

  @doc """
  Picks the most important POS if there are multiple.
  """
  def pick_primary_pos(pos_list) do
    priority = [:interjection, :verb, :noun, :adjective, :adverb, :preposition, :conjunction]

    Enum.find(priority, fn p -> p in pos_list end) || hd(pos_list)
  end

  @doc """
  Attempts to merge token structs into multiword phrases based on Brain.
  """
  def merge_multiword_phrases(tokens) do
    do_merge(tokens, [], [])
  end

  defp do_merge([], acc, _), do: Enum.reverse(acc)

  defp do_merge([t1 | rest], acc, build) do
    build = build ++ [t1]
    phrase = Enum.map(build, & &1.text) |> Enum.join(" ")

    case Brain.get(phrase) do
      %BrainCell{pos: pos} = _cell ->
        pos_list = 
          case pos do
            l when is_list(l) -> l
            nil -> [:unknown]
            other -> [other]
          end
        merged_token = %Token{
          text: phrase,
          pos: normalize_all_pos(pos_list),
          source: :merged,
          embedded_vector: nil
        }

        do_merge(rest, [merged_token | acc], [])

      nil when length(build) < @multiword_cutoff ->
        do_merge(rest, acc, build)

      _ ->
        [head | tail] = build
        do_merge([head | rest], acc ++ [head], [])
    end
  end

  @doc """
  Generates a Cartesian product of POS combinations.
  """
  def cartesian_product([head | tail]) do
    Enum.reduce(tail, Enum.map(head, fn h -> [h] end), fn list, acc ->
      for x <- acc, y <- list, do: x ++ [y]
    end)
  end

  def cartesian_product([]), do: []
end

