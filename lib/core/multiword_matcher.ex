defmodule Core.MultiwordMatcher do
  @moduledoc """
  Merge known Multi-Word Expressions (MWEs) into a single %Core.Token{} safely.

  - Accepts tokens as %Core.Token{} or raw binaries; coerces to tokens.
  - Only merges multi-word phrases (length >= 2).
  - Always advances the scan index (no hangs like "hello there").
  - Uses Core.MultiwordPOS for phrases and coarse POS.
  - Caches index with :persistent_term.
  """

  alias Core.{Token, MultiwordPOS}

  @pt_key {__MODULE__, :index}

  # ---------- public API ----------

  @doc """
  Refresh the cached index from MultiwordPOS phrases. Idempotent.
  """
  def refresh! do
    phrases =
      MultiwordPOS.phrases()
      |> Enum.map(&String.downcase/1)
      |> Enum.map(&String.trim/1)
      |> Enum.uniq()

    # Only multi-word phrases are candidates for merging
    mwes =
      phrases
      |> Enum.filter(&String.contains?(&1, " "))
      |> Enum.map(&String.split(&1, " "))

    first_map =
      mwes
      |> Enum.reduce(%{}, fn words = [first | _], acc ->
        Map.update(acc, first, [words], fn list -> [words | list] end)
      end)
      |> Enum.into(%{}, fn {k, lists} ->
        {k, Enum.sort_by(lists, &length/1, :desc)} # longest-first
      end)

    maxlen = Enum.reduce(mwes, 0, fn w, acc -> max(acc, length(w)) end)
    :persistent_term.put(@pt_key, {first_map, maxlen})
    :ok
  end

  @doc """
  Return the cached index; builds it on first call.
  """
  def index do
    case :persistent_term.get(@pt_key, :missing) do
      :missing ->
        refresh!()
        :persistent_term.get(@pt_key)

      tuple ->
        tuple
    end
  end

  @doc """
  Merge known multi-word phrases into single tokens.

  Guarantees forward progress and never tries to merge single words.
  Accepts a list of %Core.Token{} or binaries.
  """
  def merge_words([]), do: []
  def merge_words(tokens) when is_list(tokens) do
    tokens = Enum.map(tokens, &coerce_token/1)
    {first_map, _maxlen} = index()

    words = Enum.map(tokens, &token_norm_text/1)
    do_merge(tokens, words, first_map, 0, [])
  end

  @doc """
  Optional single-token POS override for the Tokenizer.

  If a single token is a known phrase in MultiwordPOS (e.g., "hello", "please", "what"),
  return a one-element POS list like [:interjection] / [:particle] / [:wh]. Otherwise nil.
  """
  @spec pos_override(binary()) :: [atom()] | nil
 # Accept either a %Core.Token{} or a binary; fall back to nil for anything else.
# Returns a single-element POS list (e.g., [:interjection]) or nil.
def pos_override(%Core.Token{} = t) do
  s = (t.phrase || t.text || "") |> to_string()
  pos_override(s)
end

def pos_override(token) when is_binary(token) do
  case Core.MultiwordPOS.lookup(token) do
    nil -> nil
    tag -> [tag]
  end
end

def pos_override(_), do: nil
 
  # ---------- internal: merge loop ----------

  defp do_merge(tokens, words, first_map, i, acc) do
    n = length(tokens)

    if i >= n do
      Enum.reverse(acc)
    else
      t = :lists.nth(i + 1, tokens)   # 1-based
      w = :lists.nth(i + 1, words)

      candidates = Map.get(first_map, w, [])

      case longest_match_len(words, i, candidates) do
        l when is_integer(l) and l >= 2 ->
          phrase_words = Enum.slice(words, i, l)
          phrase = Enum.join(phrase_words, " ")

          pos =
            case MultiwordPOS.lookup(phrase) do
              nil -> []
              tag -> [tag]
            end

          merged = %Token{t | phrase: phrase, pos: pos}
          do_merge(tokens, words, first_map, i + l, [merged | acc])

        _ ->
          do_merge(tokens, words, first_map, i + 1, [t | acc])
      end
    end
  end

  defp longest_match_len(words, i, candidates) do
    Enum.find_value(candidates, fn cand_words ->
      if slice_eq?(words, i, cand_words), do: length(cand_words), else: nil
    end)
  end

  defp slice_eq?(words, i, pattern_words) do
    Enum.zip(pattern_words, Enum.slice(words, i, length(pattern_words)))
    |> Enum.all?(fn {a, b} -> a == b end)
  end

  # ---------- coercion & normalization ----------

  # Accept both %Token{} and binaries; coerce to %Token{}
  defp coerce_token(%Token{} = t), do: t
  defp coerce_token(s) when is_binary(s), do: %Token{text: s, pos: []}
  defp coerce_token(other), do: %Token{text: to_string(other), pos: []}

  # Normalized token text for matching (phrase if present else text)
  defp token_norm_text(%Token{} = t) do
    (t.phrase || t.text || "")
    |> to_string()
    |> String.downcase()
    |> String.trim()
  end
end

