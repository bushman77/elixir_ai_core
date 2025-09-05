defmodule Core.MultiwordPOS do
  @moduledoc """
  Minimal multiword phrase -> coarse POS lookup used by the POS/tagging path.
  Features:
    - Case/whitespace normalization (handles '   Good   Morning  ').
    - Curly/straight apostrophes normalization (handles “what’s the time”).
    - Exact match first, then prefix match with a *word boundary* so
      'where isthmus …' does NOT trigger 'where is'.
  """

  # canonical, lowercase, single-spaced keys
  @phrases %{
    # greetings / courtesy
    "hello"                => :interjection,
    "hi"                   => :interjection,
    "hey"                  => :interjection,
    "yo"                   => :interjection,
    "good morning"         => :interjection,
    "good afternoon"       => :interjection,
    "good evening"         => :interjection,
    "thank you"            => :interjection,
    "thanks a lot"         => :interjection,
    "excuse me"            => :interjection,
    "please and thank you" => :particle,
    "please"               => :particle,

    # WH starters / common bigrams
    "what is"              => :wh,   # <- add this
    "what time"            => :wh,
    "what's the time"      => :wh,   # straight apostrophe
    "whats the time"       => :wh,   # apostrophe lost by external cleaners
    "where is"             => :wh,
    "who is"               => :wh,
    "when is"              => :wh,
    "why is"               => :wh,
    "how much"             => :wh,
    "how many"             => :wh,
    "how long"             => :wh,

    # command-ish phrases (tests expect :verb)
    "show me"              => :verb,
    "tell me"              => :verb,
    "give me"              => :verb,
    "look up"              => :verb,
    "lookup"               => :verb,
    "find"                 => :verb,
    "open"                 => :verb,
    "check"                => :verb
  }

  @phrase_list @phrases |> Map.keys() |> Enum.sort()  # deterministic for tests

  @doc "Returns the normalized phrase list (used in tests)."
  def phrases, do: @phrase_list

  @doc """
  Looks up a phrase and returns a coarse POS atom or nil.

  - Exact match first.
  - Then prefix match **with word boundary**. Examples:
      * 'where is the station' -> :wh
      * 'where isthmus located' -> nil (no false positive)
  """
  @spec lookup(binary() | nil) :: atom() | nil
  def lookup(nil), do: nil
  def lookup(s) when is_binary(s) do
    norm = normalize(s)

    Map.get(@phrases, norm) ||
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
  defp boundary_match?(s, key) do
    if String.starts_with?(s, key) do
      next = String.at(s, String.length(key))
      next in [nil, " ", "\t", "\n", "\r", ".", ",", "!", "?", ";", ":"]
    else
      false
    end
  end
end

