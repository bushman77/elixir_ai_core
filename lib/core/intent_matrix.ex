defmodule Core.IntentMatrix do
  @moduledoc """
  Intent classification based on scoring weighted patterns from token POS lists.
  Uses confidence scoring for better intent decisions.
  """

  @intent_patterns %{
    greeting: [
      {"interjection", 1.0},
      {"interjection", 0.8},
      {"interjection", 0.5},
      {"noun", 0.3},
      {"pronoun", 0.3}
    ],
    question: [
      {"wh_pronoun", 1.0},
      {"aux", 0.9},
      {"modal", 0.8},
      {"verb", 0.6},
      {"pronoun", 0.4}
    ],
    command: [
      {"verb", 1.0},
      {"noun", 0.3},
      {"pronoun", 0.3}
    ],
    affirmation: [
      {"affirmative", 1.0},
      {"interjection", 0.6},
      {"pronoun", 0.3}
    ],
    negation: [
      {"negation", 1.0},
      {"aux", 0.8},
      {"pronoun", 0.4}
    ]
  }

  @threshold 1.5

  @doc """
  Classifies an intent based on list of token maps (%{word, pos}).
  """
  def classify(tokens) when is_list(tokens) do
    scores =
      Enum.reduce(@intent_patterns, %{}, fn {intent, pattern_weights}, acc ->
        score =
          Enum.reduce(tokens, 0.0, fn %{pos: pos_list}, sum ->
            sum + score_token(pos_list, pattern_weights)
          end)

        Map.put(acc, intent, score)
      end)

    {intent, confidence} = Enum.max_by(scores, fn {_intent, score} -> score end, fn -> {:unknown, 0.0} end)

    if confidence >= @threshold do
      %{intent: intent, confidence: confidence}
    else
      %{intent: :unknown, confidence: confidence}
    end
  end

  defp score_token(pos_list, pattern_weights) do
    Enum.reduce(pattern_weights, 0.0, fn {pos, weight}, acc ->
      if pos in pos_list, do: acc + weight, else: acc
    end)
  end
end

