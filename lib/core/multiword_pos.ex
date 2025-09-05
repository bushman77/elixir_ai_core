defmodule Core.MultiwordPOS do
  @moduledoc """
  Minimal multiword phrase -> coarse POS lookup used by the POS/tagging path.

  Features:
    - Case/whitespace normalization (handles '   Good   Morning  ').
    - Curly/straight apostrophes normalization (handles “what’s the time”).
    - Exact match first, then prefix match with a *word boundary* so
      'where isthmus …' does NOT trigger 'where is'.
  """

  # single-word WH starters (exact-match only)
  @wh_single ~w(what when where who why how)

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

    # WH starters / common bigrams & contractions
    "what is"              => :wh,
    "what time"            => :wh,
    "what's the time"      => :wh,   # straight apostrophe
    "whats the time"       => :wh,   # apostrophe lost by external cleaners
    "what's"               => :wh,
    "where is"             => :wh,
    "where's"              => :wh,
    "who is"               => :wh,
    "who's"                => :wh,
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

  Order:
    1) exact match against @phrases
    2) exact match for single-word WH starters
    3) prefix match with word boundary for all keys EXCEPT single-word WH
  """
  @spec lookup(binary() | nil) :: atom() | nil
  def lookup(nil), do: nil
  def lookup(s) when is_binary(s) do
    norm = normalize(s)

    # 1) exact map hit
    Map.get(@phrases, norm)
    # 2) exact WH-single hit
    || (norm in @wh_single && :wh)
    # 3) boundary prefix (skip single-word WH keys to prevent 'where isthmus' FP)
    || Enum.find_value(@phrase_list, fn key ->
         val = Map.fetch!(@phrases, key)
         if single_word?(key) and val == :wh do
           nil
         else
           if boundary_match?(norm, key), do: val, else: nil
         end
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

  defp single_word?(key), do: not String.contains?(key, " ")

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

