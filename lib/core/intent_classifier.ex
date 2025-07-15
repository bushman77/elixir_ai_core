defmodule Core.IntentClassifier do
  @moduledoc "Classifies intent based on POS combinations."

  @intents [:greeting, :farewell, :question, :command, :request, :statement, :affirmation, :negation, :exclamation]

  @patterns %{
    greeting: [["interjection"], ["interjection", "pronoun"]],
    farewell: [["interjection", "pronoun"]],
    question: [["verb", "pronoun"], ["aux", "pronoun"]],
    command: [["verb"], ["verb", "noun"]],
    request: [["verb", "pronoun", "noun"], ["verb", "noun"]],
    statement: [["pronoun", "verb"], ["noun", "verb"]],
    affirmation: [["adverb"], ["adverb", "verb"]],
    negation: [["adverb", "verb"], ["adverb", "pronoun"]],
    exclamation: [["interjection", "noun"]]
  }

  def classify(tokens) do
    pos_lists = Enum.map(tokens, & &1.pos)
    combos = build_combinations(pos_lists)

    Enum.each(@intents, fn intent ->
      IO.puts("⏳ Trying intent: #{intent}")
    end)

    matched =
      Enum.find(@intents, fn intent ->
        Enum.any?(combos, fn combo -> match_pattern?(intent, combo) end)
      end)

    {:ok,
     %{
       tokens: tokens,
       intent: matched || :unknown,
       keyword: extract_keyword(tokens)
     }}
  end

  defp match_pattern?(intent, pos_combo) do
    Enum.any?(@patterns[intent] || [], fn pattern ->
      pos_combo == pattern
    end)
  end

  defp build_combinations(pos_lists) do
    pos_lists
    |> Enum.map(&Enum.uniq/1)
    |> combine()
  end

  defp combine([head | tail]) do
    Enum.reduce(tail, Enum.map(head, &[&1]), fn list, acc ->
      for x <- acc, y <- list, do: x ++ [y]
    end)
  end

  defp combine([]), do: []

  defp extract_keyword([%{word: word} | _]), do: word
  defp extract_keyword(_), do: "that"
end

