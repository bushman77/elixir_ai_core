defmodule ElixirAiCore.PhraseClassifier do
  @moduledoc "Classifies clauses and phrase structures for semantic resolution"

  def classify(tokens) when is_binary(tokens) do
    tokens
    |> ElixirAiCore.Tokenizer.tokenize()
    |> classify()
  end

  def classify(tokens) when is_list(tokens) do
    Enum.reduce(tokens, %{verb_phrase: [], infinitive_phrase: [], adverb_modifiers: [], structure: nil}, fn %{word: word, pos: pos}, acc ->
      cond do
        :verb in pos and acc.structure == nil ->
          %{acc | verb_phrase: acc.verb_phrase ++ [word], structure: :main_clause}

        :adverb in pos and word == "only" ->
          %{acc | adverb_modifiers: acc.adverb_modifiers ++ [word]}

        :preposition in pos and word == "to" ->
          %{acc | structure: :purpose_clause, infinitive_phrase: [word]}

        acc.structure == :purpose_clause and (:verb in pos or :interjection in pos or :noun in pos) ->
          %{acc | infinitive_phrase: acc.infinitive_phrase ++ [word]}

        true ->
          acc
      end
    end)
  end
end

