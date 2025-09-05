defmodule Core.MultiwordPOS do
  @moduledoc """
  Multiword POS lookup + phrase inventory for the MultiwordMatcher.

  - `lookup/1` returns a POS atom or nil.
  - `phrases/0` returns normalized phrases that the matcher should index.

  Covers:
    * Greetings: hello/hi/hey/yo/greetings/howdy/sup (+ optional “there”).
    * Greeting MWEs: “good morning/afternoon/evening”.
    * Courtesy/thanks: "thank you", "thanks a lot", "please and thank you".
    * WH: single words (what/when/where/who/why/how) and “what is”, “where is”,
          “who is”, “what time”, “how much” (+ contraction expansion).
    * Command-ish: “help”, “help me/with/out”, “please help”, “help please”.
    * Word-boundary prefix (“where is …” won’t match “where isthmus …”).
  """

  @greetings ~w(hello hi hey yo greetings howdy sup)

  # phrase -> POS
  @phrase_pos %{
    # greetings (MWEs)
    "good morning"         => :interjection,
    "good afternoon"       => :interjection,
    "good evening"         => :interjection,

    # thanks / courtesy
    "thank you"            => :interjection,
    "thanks a lot"         => :interjection,
    "please and thank you" => :particle,

    # WH phrases
    "what is"              => :wh,
    "where is"             => :wh,
    "who is"               => :wh,
    "what time"            => :wh,
    "how much"             => :wh,

    # command-ish
    "help"                 => :verb,
    "help me"              => :verb,
    "help with"            => :verb,
    "help out"             => :verb,
    "please help"          => :verb,
    "help please"          => :verb
  }

  @doc "Return a POS atom or nil for the given phrase/sentence."
  @spec lookup(String.t()) :: atom() | nil
  def lookup(phrase) when is_binary(phrase) do
    norm =
      phrase
      |> normalize()
      |> expand_contractions()
      |> strip_trailing_punct()
      |> squish()

    cond do
      # single-word greeting or greeting + 'there'
      Regex.match?(~r/^(hello|hi|hey|yo|greetings|howdy|sup)(\s+there)?$/u, norm) ->
        :interjection

      # single-word WH or exact short WH starters
      Regex.match?(~r/^(what|when|where|who|why|how)(\s+(is|are|time|much))?$/u, norm) ->
        :wh

      # flexible command-ish “help …”
      Regex.match?(~r/^(please\s+)?(help|assist|support)(\s+(me|with|out|please))?$/u, norm) ->
        :verb

      # exact phrase table
      Map.has_key?(@phrase_pos, norm) ->
        Map.fetch!(@phrase_pos, norm)

      true ->
        # prefix phrase with word boundary, e.g., "where is the station"
        # (requires a space after the phrase; avoids "where isthmus …")
        prefixed_phrase_pos(norm)
    end
  end

  def lookup(_), do: nil

  @doc "List of normalized phrases for the matcher to index."
  @spec phrases() :: [String.t()]
  def phrases, do: Map.keys(@phrase_pos)

  # ---------- helpers ----------

  defp prefixed_phrase_pos(norm) do
    Map.keys(@phrase_pos)
    |> Enum.sort_by(&String.length/1, :desc)
    |> Enum.find_value(fn p ->
      if String.starts_with?(norm, p <> " ") do
        Map.fetch!(@phrase_pos, p)
      else
        nil
      end
    end)
  end

  defp normalize(s) when is_binary(s), do: String.downcase(String.trim(s))
  defp normalize(_), do: ""

  defp squish(s), do: String.replace(s, ~r/[[:space:]]+/, " ")

  # tolerate trailing punctuation like "hi!!!", "help?", "thanks a lot."
  defp strip_trailing_punct(s), do: String.replace(s, ~r/[\s]*[!?,;:…\.]+$/u, "")

  # expand curly/straight apostrophes in common WH contractions
  defp expand_contractions(s) do
    s
    |> String.replace("what’s",  "what is")
    |> String.replace("what's",  "what is")
    |> String.replace("where’s", "where is")
    |> String.replace("where's","where is")
    |> String.replace("who’s",   "who is")
    |> String.replace("who's",   "who is")
    |> String.replace("how’s",   "how is")
    |> String.replace("how's",   "how is")
  end
end

