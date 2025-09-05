defmodule Core.MultiwordPOS do
  @moduledoc """
  Minimal multiword phrase -> coarse POS lookup used by the POS/tagging path.

  Features:
    - Case/whitespace normalization (handles '   Good   Morning  ').
    - Curly/straight apostrophes normalization (handles “what’s the time”).
    - Exact match first, then prefix match with a *word boundary* so
      'where isthmus …' does NOT trigger 'where is'.
  """

  # single-word WH starters the tests expect to resolve as :wh on exact match
  @wh_single ~w(what where who when why how)

  # canonical, lowercase, single-spaced keys
  @phrases %{
    # greetings / courtesy
    "hello"                => :interjection,
    "hi"                   => :interjection,
    "hey"                  => :interjection,
    "yo"                   => :interjection,
    "sup"                  => :interjection,   # extra greeting coverage
    "good morning"         => :interjection,
    "good afternoon"       => :interjection,
    "good evening"         => :interjection,
    "good day"             => :interjection,
    "thank you"            => :interjection,
    "thanks"               => :interjection,
    "thanks a lot"         => :interjection,
    "excuse me"            => :interjection,
    "please and thank you" => :particle,
    "please"               => :particle,

    # WH starters / common bigrams
    "what is"         => :wh,
    "what time"       => :wh,
    "what's the time" => :wh,  # straight apostrophe
    "whats the time"  => :wh,  # apostrophe lost by external cleaners
    "where is"        => :wh,
    "who is"          => :wh,
    "when is"         => :wh,
    "why is"          => :wh,
    "how much"        => :wh,
    "how many"        => :wh,
    "how long"        => :wh,

    # Common “’s the …” contractions for WH
    "where's the"     => :wh,
    "who's the"       => :wh,
    "when's the"      => :wh,
    "what's the"      => :wh,

    # command-ish phrases (tests expect :verb)
    "show me"         => :verb,
    "tell me"         => :verb,
    "give me"         => :verb,
    "look up"         => :verb,
    "lookup"          => :verb,
    "search for"      => :verb,
    "search"          => :verb,
    "find"            => :verb,
    "open"            => :verb,
    "check"           => :verb
  }

  @phrase_list @phrases |> Map.keys() |> Enum.sort()  # deterministic for tests

  @doc "Returns the normalized phrase list (used in tests)."
  def phrases, do: @phrase_list

  @doc """
  Looks up a phrase and returns a coarse POS atom or nil.

  Order:
    1) exact match in @phrases
    2) exact match of single-word WH starters
    3) prefix match **with word boundary** against @phrases
  """
  @spec lookup(binary() | nil) :: atom() | nil
  def lookup(nil), do: nil
  def lookup(s) when is_binary(s) do
    norm = normalize(s)

    # 1) exact phrase
    Map.get(@phrases, norm) ||
      # 2) exact single-word WH (only exact, no prefix here)
      (norm in @wh_single && :wh) ||
      # 3) prefix with boundary
      Enum.find_value(@phrase_list, fn key ->
        if boundary_match?(norm, key), do: Map.fetch!(@phrases, key), else: nil
      end)
  end

  # ---------- helpers ----------

  defp normalize(s) do
    s
    |> String.downcase()
    |> String.replace(~r/[’‘]/u, "'")   # curly -> straight
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # Starts-with + next char must be a boundary (or end of string)
  # Ensures "where isthmus ..." does NOT match "where is"
  defp boundary_match?(s, key) do
    if String.starts_with?(s, key) do
      next = String.at(s, String.length(key))
      next in [nil, " ", "\t", "\n", "\r", ".", ",", "!", "?", ";", ":"]
    else
      false
    end
  end
end

