defmodule Core.MultiwordMatcher do
  @moduledoc """
  Finds and merges known multiword expressions (MWEs) in a token stream.
  Also exposes POS overrides for merged phrases.
  """

  alias Core.MultiwordPOS

  @doc """
  All known phrases (must be lowercase, space-separated).
  Delegates to your MultiwordPOS to keep a single source of truth.
  """
  @spec get_phrases() :: [binary()]
  def get_phrases, do: MultiwordPOS.phrases()

  @doc """
  POS override for a merged phrase (returns an atom tag or nil).
  """
  @spec pos_override(binary()) :: atom() | nil
  def pos_override(phrase) when is_binary(phrase) do
    # phrases are stored lowercase; normalize input
    MultiwordPOS.lookup(String.downcase(phrase))
  end

  @doc """
  Merge a *list of downcased words* into phrases using longest-match-first.
  Returns a list of strings where matched MWEs appear as a single element.
  """
  @spec merge_words([binary()]) :: [binary()]
  def merge_words(words) when is_list(words) do
    {first_map, _maxlen} = phrase_index()

    do_merge(words, first_map, [])
  end

  # ---------- internal ----------

  # Pre-index phrases by their first token, sort each bucket by length desc
  # Returns {first_map, maxlen}
  defp phrase_index do
    phrases =
      get_phrases()
      |> Enum.map(fn p ->
        parts = String.split(p, ~r/\s+/, trim: true)
        {p, parts, length(parts)}
      end)

    maxlen = Enum.reduce(phrases, 1, fn {_p, _parts, len}, acc -> max(acc, len) end)

    first_map =
      phrases
      |> Enum.group_by(fn {_p, parts, _len} -> hd(parts) end)
      |> Enum.into(%{}, fn {first, lst} ->
        # longest first to prefer the most specific match
        sorted = Enum.sort_by(lst, fn {_p, _parts, len} -> -len end)
        {first, sorted}
      end)

    {first_map, maxlen}
  end

  defp do_merge([], _first_map, acc), do: Enum.reverse(acc)

  defp do_merge([w | rest] = words, first_map, acc) do
    case Map.get(first_map, w) do
      nil ->
        do_merge(rest, first_map, [w | acc])

      candidates ->
        # try each candidate (already longest-first) and take the first that fits
        case try_match(words, candidates) do
          {:ok, phrase, skip} ->
            do_merge(Enum.drop(words, skip), first_map, [phrase | acc])

          :nomatch ->
            do_merge(rest, first_map, [w | acc])
        end
    end
  end

  defp try_match(words, candidates) do
    Enum.find_value(candidates, :nomatch, fn {phrase, parts, len} ->
      if Enum.take(words, len) == parts, do: {:ok, phrase, len}, else: false
    end)
  end
end

