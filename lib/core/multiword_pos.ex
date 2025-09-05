defmodule Core.MultiwordPOS do
  @moduledoc """
  Minimal multiword phrase → coarse POS lookup used by the POS/tagging path.

  Features:
    • Case/whitespace normalization (handles `"   Good   Morning  "`).
    • Curly/straight apostrophes normalization (handles “what’s the time”).
    • Exact match first, then prefix match with a *word boundary* so
      `"where isthmus …"` does NOT trigger `"where is"`.
  """

  # Single-word WH starters should be exact-match only
  @wh_single ~w(what when where who why how)

  # Canonical, lowercase, single-spaced keys
  @phrases %{
    # greetings / courtesy
    "hello"                => :interjection,
    "hi"                   => :interjection,
    "hey"                  => :interjection,
    "yo"                   => :interjection,
    "sup"                  => :interjection,
    "good morning"         => :interjection,
    "good afternoon"       => :interjection,
    "good evening"         => :interjection,
    "see you later"        => :interjection,
    "thank you"            => :interjection,
    "thanks a lot"         => :interjection,
    "excuse me"            => :interjection,
    "please and thank you" => :particle,
    "please"               => :particle,

    # WH starters / common bigrams & contractions
    "what is"              => :wh,
    "what time"            => :wh,
    "what's the time"      => :wh,
    "whats the time"       => :wh,  # when apostrophe is stripped upstream
    "what's"               => :wh,

    "where is"             => :wh,
    "where's"              => :wh,

    "who is"               => :wh,
    "who's"                => :wh,
    "who are"              => :wh,

    "when is"              => :wh,
    "when will"            => :wh,

    "why is"               => :wh,
    "how much"             => :wh,
    "how many"             => :wh,
    "how long"             => :wh,

    # command-ish phrases (tests expect :verb)
    "show"                 => :verb,
    "tell"                 => :verb,
    "give"                 => :verb,
    "search"               => :verb,
    "get"                  => :verb,
    "find"                 => :verb,
    "open"                 => :verb,
    "check"                => :verb,
    "look for"             => :verb,
    "look up"              => :verb,
    "lookup"               => :verb,
    "show me"              => :verb,
    "tell me"              => :verb,
    "give me"              => :verb,
    "turn on"              => :verb,
    "turn off"             => :verb,
    "log out"              => :verb,
    "sign in"              => :verb,
    "sign up"              => :verb
  }

  @phrase_list @phrases |> Map.keys() |> Enum.sort()  # deterministic for tests

  @doc "Returns the normalized phrase list (used in tests)."
  def phrases, do: @phrase_list

  @doc """
  Looks up a phrase and returns a coarse POS atom or nil.

  Order:
    1) exact match against @phrases
    2) exact match for single-word WH starters
    3) prefix match with word boundary for all keys EXCEPT plain single-word WH
       (we still allow contracted single-word WH like "what's", "where's").
  """
  @spec lookup(binary() | nil) :: atom() | nil
  def lookup(nil), do: nil
  def lookup(s) when is_binary(s) do
    norm = normalize(s)

    Map.get(@phrases, norm) ||
      # exact match for plain single-word WH (no prefix use)
      if(norm in @wh_single, do: :wh, else:
        # boundary prefix match for all other keys
        Enum.find_value(@phrase_list, fn key ->
          val = Map.fetch!(@phrases, key)
          if not plain_single_wh_key?(key, val) and boundary_match?(norm, key), do: val, else: nil
        end)
      )
  end

  # ---------- helpers ----------

  defp normalize(s) do
    s
    |> String.downcase()
    |> String.replace(~r/[’‘]/u, "'") # curly -> straight apostrophes
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp plain_single_wh_key?(key, val) do
    val == :wh and
      not String.contains?(key, " ") and
      not String.contains?(key, "'")
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

