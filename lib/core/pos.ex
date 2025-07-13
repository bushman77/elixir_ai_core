defmodule Core.POS do
  @moduledoc """
  Part-of-speech utilities and intent classification based on POS patterns and fallback keyword matching.

  Supports intents like:
    - question
    - greeting
    - affirmation
    - command
    - etc.
  """

  @greeting_words ~w(hello hi hey greetings welcome)
  @affirmative_words ~w(yes yeah yup sure certainly absolutely)

  @intent_patterns %{
    question: [
      ["adverb", "verb", "pronoun"],
      ["wh_pronoun", "verb", "noun"],
      ["wh_determiner", "noun", "verb"],
      ["verb", "pronoun"],
      ["aux", "pronoun", "verb"],
      ["modal", "pronoun", "base_verb"],
      ["preposition", "noun", "verb"],
      ["wh_adverb", "aux", "subject"],
      ["interjection", "verb", "pronoun"],
      ["pronoun", "verb", "pronoun", "verb"]
    ],
    command: [
      ["verb"],
      ["verb", "noun"],
      ["verb", "object"],
      ["verb", "preposition", "noun"],
      ["verb", "pronoun"],
      ["modal", "verb"]
    ],
    statement: [
      ["pronoun", "verb"],
      ["noun", "verb"],
      ["subject", "verb", "object"],
      ["pronoun", "aux", "verb"],
      ["noun", "aux", "verb"],
      ["determiner", "noun", "verb"]
    ],
    greeting: [
      ["interjection"],
      ["interjection", "pronoun"],
      ["interjection", "noun"]
    ],
    exclamation: [
      ["interjection", "exclamation"],
      ["adjective", "exclamation"],
      ["interjection", "adjective"]
    ],
    negation: [
      ["pronoun", "aux", "negation", "verb"],
      ["noun", "aux", "negation", "verb"],
      ["aux", "negation", "verb"]
    ],
    request: [
      ["modal", "pronoun", "verb"],
      ["verb", "pronoun", "please"],
      ["please", "verb", "noun"]
    ],
    affirmation: [
      ["yes"],
      ["affirmative"],
      ["pronoun", "verb", "noun"],
      ["pronoun", "aux", "verb"],
      ["pronoun", "modal", "base_verb"],
      ["interjection", "affirmative"],
      ["pronoun", "verb", "affirmative"]
    ]
  }

  @doc """
  Classifies a list of token maps with POS tags.
  """
  def classify_input(tokens) when is_list(tokens) do
    pos_lists = Enum.map(tokens, fn %{pos: pos} -> pos end)
    combos = cartesian_product(pos_lists)

    found_intent =
      Enum.find_value(Map.keys(@intent_patterns), :unknown, fn intent ->
        patterns = Map.get(@intent_patterns, intent, [])
        Enum.find(patterns, fn pattern -> pattern in combos end) && intent
      end)

    intent = fallback_intent(found_intent, tokens)
    {:answer, %{intent: intent, tokens: tokens}}
  end

  defp fallback_intent(:unknown, tokens) do
    words = Enum.map(tokens, &String.downcase(&1.word))

    cond do
      Enum.any?(words, &(&1 in @greeting_words)) -> :greeting
      Enum.any?(words, &(&1 in @affirmative_words)) -> :affirmation
      true -> :unknown
    end
  end

  defp fallback_intent(intent, _), do: intent

  defp cartesian_product([]), do: [[]]

  defp cartesian_product([head | tail]) do
    for h <- head, t <- cartesian_product(tail), do: [h | t]
  end

  @doc """
  Normalizes incoming POS from API to lowercase string.
  """
  def normalize_pos(pos) when is_binary(pos), do: String.downcase(pos)
  def normalize_pos(_), do: "unknown"

  @doc """
  Picks primary POS from a list, using a preferred order (assumes strings).
  """
  def pick_primary_pos(pos_list) when is_list(pos_list) do
    preferred_order = [
      "interjection",
      "exclamation",
      "wh_pronoun",
      "wh_determiner",
      "modal",
      "aux",
      "pronoun",
      "verb",
      "adjective",
      "noun",
      "adverb",
      "preposition",
      "determiner",
      "conjunction"
    ]

    Enum.find(preferred_order, &(&1 in pos_list)) || List.first(pos_list)
  end
end

