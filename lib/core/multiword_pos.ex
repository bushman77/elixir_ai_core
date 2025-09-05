defmodule Core.MultiwordPOS do
  @moduledoc """
  Minimal multiword-expression (MWE) lexicon for fast POS hints.

  * `lookup/1` returns a POS tag atom or `nil`.
  * `phrases/0` exposes the exact-phrase keys (normalized).
  * Case/space are normalized; straight/curly apostrophes are unified.
  * Includes:
    - greetings: "good morning/afternoon/evening", "thank you", "thanks a lot"
    - WH starters (exact): "what time", "how much"
    - Command-ish: "please help", "help me", "show me", "tell me"
  * Prefix WH safety: matches start-of-string with **word boundary** (e.g.
    `"where is the station"` -> `:wh`, but `"where isthmus ..."` -> `nil`).
  """

  @type pos_tag :: :interjection | :wh | :verb

  # ---- exact phrase table (all lowercased, single-spaced) ----
  @phrase_map %{
    # greetings
    "good morning" => :interjection,
    "good afternoon" => :interjection,
    "good evening" => :interjection,
    "thank you" => :interjection,
    "thanks a lot" => :interjection,
    "thanks so much" => :interjection,

    # WH exact bigrams
    "what time" => :wh,
    "how much" => :wh,

    # command-ish phrases
    "please help" => :verb,
    "help me" => :verb,
    "show me" => :verb,
    "tell me" => :verb
  }

  # ---- prefix rules (word-boundary) ----
  # We keep these short and safe; they only fire at the beginning of the string.
  @wh_prefixes [
    "where is",
    "what is",
    "who is",
    "when is",
    "why is",
    "how much",
    "how many",
    "what time"
  ]

  @doc "Returns the list of exact phrases recognized (normalized)."
  @spec phrases() :: [String.t()]
  def phrases, do: Map.keys(@phrase_map)

  @doc """
  Lookup a phrase → POS tag.

  1) exact match (normalized)
  2) WH prefix with word-boundary (beginning only)
  3) fallback: `nil`
  """
  @spec lookup(String.t()) :: pos_tag | nil
  def lookup(nil), do: nil

  def lookup(phrase) when is_binary(phrase) do
    s = normalize(phrase)

    cond do
      s == "" ->
        nil

      pos = Map.get(@phrase_map, s) ->
        pos

      wh_prefix?(s) ->
        :wh

      true ->
        nil
    end
  end

  # ---- helpers ----

  defp wh_prefix?(s) do
    Enum.any?(@wh_prefixes, fn pfx ->
      # enforce word boundary after the prefix to avoid "isthmus" false hits
      # ^pfx\b
      # Build a safe regex per prefix.
      {:ok, re} = Regex.compile("^" <> Regex.escape(pfx) <> "\\b")
      Regex.match?(re, s)
    end)
  end

  defp normalize(s) do
    s
    |> String.downcase()
    |> unify_apostrophes()
    |> expand_contractions()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # unify straight/curly apostrophes
  defp unify_apostrophes(s), do: String.replace(s, ~r/[’]/u, "'")

  # very small expansion set just to help WH patterns commonly seen in tests
  defp expand_contractions(s) do
    s
    |> String.replace(~r/\bwhat's\b/, "what is")
    |> String.replace(~r/\bwho's\b/, "who is")
    |> String.replace(~r/\bwhere's\b/, "where is")
    |> String.replace(~r/\bwhen's\b/, "when is")
    |> String.replace(~r/\bwhy's\b/, "why is")
    |> String.replace(~r/\bhow's\b/, "how is")
  end
end

