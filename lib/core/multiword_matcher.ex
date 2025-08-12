defmodule Core.MultiwordMatcher do
  @moduledoc """
  Finds and merges known multiword expressions (MWEs) in a token stream.
  Also exposes POS overrides for merged phrases.

  Sources:
    • Core.MultiwordPOS.phrases/0 is the single source of truth.
  Caching:
    • Builds a first-token index once and caches it in :persistent_term.
    • Call refresh!/0 after you modify phrase inventories.
  """

  alias Core.MultiwordPOS

  @cache_key {__MODULE__, :index}

  # ── Public API ────────────────────────────────────────────────────────────────

  @doc "All known phrases (lowercase, space-normalized)."
  @spec get_phrases() :: [binary()]
  def get_phrases, do: MultiwordPOS.phrases()

  @doc "POS override for a merged phrase (list of tags, [] if none)."
  @spec pos_override(binary()) :: [atom()]
  def pos_override(phrase) when is_binary(phrase) do
    MultiwordPOS.lookup(String.downcase(phrase)) || []
  end

  @doc """
  Merge a list of **downcased** words into phrases using longest-match-first.
  Returns a list of strings where matched MWEs appear as a single element.
  """
  @spec merge_words([binary()]) :: [binary()]
  def merge_words(words) when is_list(words) do
    {first_map, _maxlen, _sig} = index()
    do_merge(words, first_map, [])
  end

  @doc """
  Rebuild the cached index. Call after seeding/enrichment.
  """
  @spec refresh!() :: :ok
  def refresh! do
    phrases = get_phrases()

    # signature guards against stale cache if phrases change
    sig =
      :erlang.phash2(phrases)

    tuples =
      phrases
      |> Enum.map(fn p ->
        parts = String.split(p, ~r/\s+/, trim: true)
        {p, parts, length(parts)}
      end)

    maxlen = Enum.reduce(tuples, 1, fn {_p, _parts, len}, acc -> max(acc, len) end)

    first_map =
      tuples
      |> Enum.group_by(fn {_p, parts, _len} -> hd(parts) end)
      |> Map.new(fn {first, lst} ->
        # longest-first to prefer most specific match
        {first, Enum.sort_by(lst, fn {_p, _parts, len} -> -len end)}
      end)

    :persistent_term.put(@cache_key, {first_map, maxlen, sig})
    :ok
  end

  # ── Internal ─────────────────────────────────────────────────────────────────

  defp index do
    case :persistent_term.get(@cache_key, :missing) do
      :missing ->
        refresh!()
        :persistent_term.get(@cache_key)

      {first_map, maxlen, sig} = cached ->
        # If phrases changed (dev), rebuild automatically
        if sig != :erlang.phash2(get_phrases()) do
          refresh!()
          :persistent_term.get(@cache_key)
        else
          cached
        end
    end
  end

  defp do_merge([], _first_map, acc), do: Enum.reverse(acc)

  defp do_merge([w | rest] = words, first_map, acc) do
    case Map.get(first_map, w) do
      nil ->
        do_merge(rest, first_map, [w | acc])

      candidates ->
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

