defmodule Core.MultiwordPOS do
  @moduledoc """
  Canonical multiword expressions → POS tags.

  Notes:
  - All phrases are stored lowercase and space-normalized.
  - `lookup/1` normalizes input and handles common WH contractions like "what's" → "what is".
  - Keep tags simple and compatible with your POSEngine:
      * greetings/thanks/farewells → :interjection
      * wh-questions → :wh
      * polite particles → :particle
      * utility/common phrases → a single, reasonable tag (:verb, :noun, etc.)
  """

  @type tag :: atom()
  @type phrase :: String.t()

  # --- Base entries (phrase -> [tags]) -----------------------------------------

  @entries [
    # Greetings
    {"good morning", [:interjection]},
    {"good afternoon", [:interjection]},
    {"good evening", [:interjection]},
    {"good day", [:interjection]},
    {"good to see you", [:interjection]},
    {"how are you", [:interjection]},

    # Thanks / courtesy
    {"thank you", [:interjection]},
    {"thanks a lot", [:interjection]},
    {"much appreciated", [:interjection]},
    {"please help", [:particle]},
    {"please and thank you", [:particle]},

    # Farewells
    {"see you", [:interjection]},
    {"see you later", [:interjection]},
    {"talk to you later", [:interjection]},
    {"take care", [:interjection]},
    {"see ya", [:interjection]},

    # WH question starters
    {"what time", [:wh]},
    {"what is", [:wh]},
    {"what are", [:wh]},
    {"what's the time", [:wh]}, # contraction variant kept for clarity
    {"how much", [:wh]},
    {"how many", [:wh]},
    {"how long", [:wh]},
    {"how far",  [:wh]},
    {"how old",  [:wh]},
    {"how do i", [:wh]},
    {"where is", [:wh]},
    {"where are", [:wh]},
    {"who is",   [:wh]},
    {"who are",  [:wh]},
    {"when is",  [:wh]},
    {"when will",[:wh]},
    {"why is",   [:wh]},
    {"why are",  [:wh]},
    {"which one",[:wh]},

    # Common command-ish patterns
    {"open settings", [:verb]},
    {"turn on", [:verb]},
    {"turn off", [:verb]},
    {"log out", [:verb]},
    {"shut down", [:verb]},
    {"sign in", [:verb]},
    {"sign up", [:verb]},

    # Time/date chunks
    {"this morning", [:noun]},
    {"this afternoon", [:noun]},
    {"this evening", [:noun]},
    {"tonight", [:noun]},
    {"tomorrow morning", [:noun]},
    {"next week", [:noun]},

    # Price / weather patterns
    {"what is the weather", [:wh]},
    {"what's the weather",  [:wh]},
    {"what is the price",   [:wh]},
    {"what's the price",    [:wh]}
  ]

  # --- Build map and phrase list ----------------------------------------------

  @map Map.new(@entries)
  @phrases Map.keys(@map)

  @doc "All supported phrases (lowercase, normalized)."
  @spec phrases() :: [phrase()]
  def phrases, do: @phrases

  @doc """
  Lookup a phrase → list of POS tags.

  Normalizes input:
  - lowercase + space collapse
  - WH contractions like “what’s/where’s/who’s/how’s/when’s/why’s” → “what is/…”
  - Falls back to prefix match: if input starts with a known phrase + space, returns that phrase's tags.

  Returns [] when no mapping is found.
  """
  @spec lookup(String.t()) :: [tag()]
  def lookup(phrase) when is_binary(phrase) do
    norm     = normalize(phrase)
    expanded = expand_wh_contractions(norm)

    direct =
      Map.get(@map, norm) ||
      Map.get(@map, expanded)

    case direct do
      nil ->
        prefix_lookup(norm) ||
        prefix_lookup(expanded) ||
        []
      tags ->
        tags
    end
  end

  # --- Normalization & contraction helpers -------------------------------------

  @spec normalize(String.t()) :: String.t()
  defp normalize(s) do
    s
    |> :unicode.characters_to_nfc_binary()
    |> String.downcase()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  @spec prefix_lookup(String.t()) :: [tag()] | nil
  defp prefix_lookup(s) do
    Enum.find_value(@map, fn {k, tags} ->
      if s == k or String.starts_with?(s, k <> " "), do: tags, else: nil
    end)
  end

  @doc false
  @spec expand_wh_contractions(String.t()) :: String.t()
  defp expand_wh_contractions(s) do
    # what’s/what's -> what is, where’s -> where is, who’s -> who is, how’s -> how is, etc.
    Regex.replace(~r/\b(what|where|who|how|when|why)[’']s\b/u, s, "\\1 is")
  end
end

