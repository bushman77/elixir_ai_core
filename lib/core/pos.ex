defmodule Core.POS do
  @moduledoc """
  Part-of-speech utilities and intent classification based on POS patterns and fallback keyword matching.

  Supports intent categories like:
    - question
    - greeting
    - command
    - statement
    - request
    - negation
    - affirmation
    - exclamation
  """

  require Logger

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
  Classifies a list of token maps (with `:pos` lists) to determine sentence intent.
  """
  def classify_input(tokens) when is_list(tokens) do
    pos_lists = Enum.map(tokens, & &1.pos)
    combos = cartesian_product(pos_lists)

    IO.inspect(tokens, label: "🔍 Tokens before classification")
    IO.inspect(pos_lists, label: "🔠 POS Lists")
    IO.inspect(combos, label: "🧪 All POS Combos")

    found_intent =
      Enum.find_value(Map.keys(@intent_patterns), :unknown, fn intent ->
        patterns = Map.get(@intent_patterns, intent, [])

        IO.puts("⏳ Trying intent: #{intent}")
        Enum.each(patterns, fn pattern ->
          if pattern in combos, do: IO.puts("✅ Matched pattern: #{inspect(pattern)} for #{intent}")
        end)

        Enum.find(patterns, fn pattern -> pattern in combos end) && intent
      end)

    intent =
      case found_intent do
        :command -> if contains_interjection?(pos_lists), do: :greeting, else: :command
        :unknown -> fallback_intent(:unknown, tokens)
        _ -> found_intent
      end

    Logger.debug("[IntentClassifier] Chose intent: #{inspect(intent)} from tokens: #{inspect(tokens)}")

    {:answer, %{intent: intent, tokens: tokens}}
  end

  @doc """
  Classifies intent from a list of word/POS tuples (used for sentence-level analysis).
  Also triggers firing of brain cells.
  """
  def intent_from_word_pos_list(pos_lists) when is_list(pos_lists) do
    combos =
      cartesian_product(pos_lists)
      |> Enum.map(fn tuple_list ->
        Enum.map(tuple_list, fn
          {_, pos} -> pos
          _ -> nil
        end)
      end)

    Brain.maybe_fire_cells(pos_lists)

    found_intent =
      Enum.find_value(@intent_patterns, :unknown, fn {intent, patterns} ->
        Enum.find(patterns, fn pattern -> pattern in combos end) && intent
      end)

    intent =
      case found_intent do
        :command -> if contains_interjection?(pos_lists), do: :greeting, else: :command
        :unknown -> fallback_intent(:unknown, pos_lists)
        _ -> found_intent
      end

    intent
  end

  defp contains_interjection?(pos_lists) do
    Enum.any?(List.flatten(pos_lists), &(&1 == "interjection"))
  end

  @doc "Fallback classification when no intent pattern matches."
  defp fallback_intent(:unknown, tokens) when is_list(tokens) do
    words = Enum.map(tokens, &String.downcase(&1.word))
    pos_list = Enum.flat_map(tokens, & &1.pos)

    cond do
      Enum.any?(words, &(&1 in @greeting_words)) or
        dominant_pos?(pos_list, "interjection") -> :greeting

      Enum.any?(words, &(&1 in @affirmative_words)) -> :affirmation

      true -> :unknown
    end
  end

  defp fallback_intent(:unknown, pos_lists) when is_list(pos_lists) do
    words = Enum.map(pos_lists, fn
      [{word, _} | _] -> String.downcase(word)
      {word, _} -> String.downcase(word)
      _ -> nil
    end)

    pos_list = Enum.flat_map(pos_lists, fn
      [{_word, pos} | _] -> [pos]
      {_word, pos} -> [pos]
      _ -> []
    end)

    IO.puts("🧩 Running fallback on words: #{inspect(words)}")
    IO.puts("🔬 POS Frequency: #{inspect(Enum.frequencies(pos_list))}")
    IO.puts("⚖️ Dominant POS check: #{inspect(dominant_pos?(pos_list, "interjection"))}")

    cond do
      Enum.any?(words, &(&1 in @greeting_words)) -> :greeting
      Enum.any?(words, &(&1 in @affirmative_words)) -> :affirmation
      true -> :unknown
    end
  end

  defp fallback_intent(intent, _), do: intent

  defp dominant_pos?(pos_list, target_pos, threshold \\ 0.6) do
    freq = Enum.frequencies(pos_list)
    total = Enum.reduce(freq, 0, fn {_k, v}, acc -> acc + v end)
    score = Map.get(freq, target_pos, 0) / total
    score >= threshold
  end

  defp cartesian_product([]), do: [[]]

  defp cartesian_product([head | tail]) do
    for h <- head, t <- cartesian_product(tail), do: [h | t]
  end

  @doc """
  Normalizes incoming POS (e.g., from dictionary API).
  """
  def normalize_pos(pos) when is_binary(pos), do: String.downcase(pos)
  def normalize_pos(_), do: "unknown"

  @doc """
  Picks the most relevant POS from a list, using a preferred priority order.
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

