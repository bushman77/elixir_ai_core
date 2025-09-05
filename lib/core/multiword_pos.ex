defmodule Core.MultiwordPOS do
  @moduledoc """
  Minimal multiword/salient-phrase lexicon for POS hints used by the tokenizer
  and a few unit tests.

  * `lookup/1` → returns a POS tag atom or `nil`.
  * `phrases/0` → returns the exact-phrase keys (normalized).
  * Normalizes case/whitespace, unifies curly/straight apostrophes, and expands a few common WH contractions.
  * Supports:
    - greetings (exact & safe prefix)
    - WH starters (exact & safe prefix)
    - command-ish phrases (exact & safe prefix)
    - courtesy combo: "please and thank you" → :particle
  """

  @type pos_tag :: :interjection | :wh | :verb | :particle

  # ---------- exact phrases (lowercased, single-spaced) ----------
  @phrase_map %{
    # single-word greetings (tests expect these here, not only in POSEngine)
    "hello" => :interjection,
    "hi" => :interjection,
    "hey" => :interjection,
    "yo" => :interjection,

    # multiword greetings/courtesy
    "good morning" => :interjection,
    "good afternoon" => :interjection,
    "good evening" => :interjection,
    "thank you" => :interjection,
    "thanks a lot" => :interjection,
    "thanks so much" => :interjection,
    "please and thank you" => :particle,

    # WH exact bigrams
    "what time" => :wh,
    "how much" => :wh,
    "how many" => :wh,
    # some tests treat these two as exact as well
    "where is" => :wh,
    "what is" => :wh,

    # command-ish exacts
    "please help" => :verb,
    "help me" => :verb,
    "show me" => :verb,
    "tell me" => :verb
  }

  # ---------- safe prefixes (beginning-of-string + word boundary) ----------
  @greet_prefixes [
    "hello",
    "hi",
    "hey",
    "yo",
    "good morning",
    "good afternoon",
    "good evening"
  ]

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

  @command_prefixes [
    "please help",
    "help me",
    "show me",
    "tell me"
  ]

  @doc "Returns the list of exact phrases recognized (normalized)."
  @spec phrases() :: [String.t()]
  def phrases, do: Map.keys(@phrase_map)

  @doc """
  Lookup a phrase → POS tag.

  Order:
    1) exact match
    2) greeting prefix
    3) command-ish prefix
    4) WH prefix
    5) nil
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

      has_prefix?(s, @greet_prefixes) ->
        :interjection

      has_prefix?(s, @command_prefixes) ->
        :verb

      has_prefix?(s, @wh_prefixes) ->
        :wh

      true ->
        nil
    end
  end

  # ---------- helpers ----------

  defp has_prefix?(s, list) do
    Enum.any?(list, fn pfx ->
      # enforce ^pfx\b to avoid e.g. "where isthmus"
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

  defp unify_apostrophes(s), do: String.replace(s, ~r/[’]/u, "'")

  # small WH contraction expansion (kept minimal for tests)
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

