defmodule Core.IntentClassifier do
  @moduledoc """
  Determines user intent based on POS patterns.
  """

  alias Core.POS
  alias Core.Token

  @intent_patterns %{
    greet: [
      [:interjection, :noun],
      [:interjection],
      [:interjection, :verb]
    ],
    question: [
      [:adverb, :auxiliary, :pronoun],
      [:verb, :pronoun],
      [:adverb, :verb]
    ],
    command: [
      [:verb, :noun],
      [:verb]
    ],
    bye: [
      [:interjection],
      [:verb, :adverb]
    ]
  }

  @doc """
  Classifies intent based on token POS patterns.
  """
  def classify_tokens(tokens) do
    pos_lists = Enum.map(tokens, & &1.pos)
    combos = POS.cartesian_product(pos_lists)

    intent =
      Enum.find_value(@intent_patterns, :unknown, fn {intent, patterns} ->
        Enum.any?(patterns, &(&1 in combos)) && intent
      end)

    intent || fallback_intent(tokens)
  end

  @doc """
  Fallback intent when no pattern matches.
  """
  def fallback_intent(tokens) do
    interjections =
      Enum.count(tokens, fn %Token{pos: pos} ->
        Enum.any?(pos, &(&1 == :interjection))
      end)

    verbs =
      Enum.count(tokens, fn %Token{pos: pos} ->
        Enum.any?(pos, &(&1 == :verb))
      end)

    cond do
      interjections > 0 and verbs == 0 -> :greet
      verbs > 0 -> :command
      true -> :unknown
    end
  end
end

