defmodule Core.IntentMatrix do
  @moduledoc """
  Intent classification using weighted scoring from POS patterns.
  """

  @intent_patterns %{
    greet: [ {:interjection, 1.0}, {:interjection, 0.8}, {:noun, 0.3}, {:pronoun, 0.3} ],
    question: [ {:wh_pronoun, 1.0}, {:auxiliary, 0.9}, {:modal, 0.8}, {:verb, 0.6}, {:pronoun, 0.4} ],
    command: [ {:verb, 1.0}, {:noun, 0.3}, {:pronoun, 0.3} ],
    affirmation: [ {:affirmative, 1.0}, {:interjection, 0.6}, {:pronoun, 0.3} ],
    negation: [ {:negation, 1.0}, {:auxiliary, 0.8}, {:pronoun, 0.4} ]
  }

  @threshold 1.2

  @doc """
  Classifies a list of token maps (%{word, pos}) by weighted POS matching.
  """
  def classify(tokens) when is_list(tokens) do
    scores =
      Enum.map(@intent_patterns, fn {intent, pattern_weights} ->
        {score, keyword, dominant_pos} = score_tokens(tokens, pattern_weights)
        {intent, %{score: score, keyword: keyword, dominant_pos: dominant_pos}}
      end)

    {best_intent, %{score: best_score, keyword: kw, dominant_pos: pos}} =
      Enum.max_by(scores, fn {_i, %{score: s}} -> s end, fn -> {:unknown, %{score: 0.0}} end)

    if best_score >= @threshold do
      %{intent: best_intent, confidence: best_score, keyword: kw, dominant_pos: pos}
    else
      %{intent: :unknown, confidence: best_score, keyword: kw, dominant_pos: pos}
    end
  end

  defp score_tokens(tokens, pattern_weights) do
    Enum.reduce(tokens, {0.0, nil, nil}, fn %{word: word, pos: pos_list}, {acc, kw, dom_pos} ->
      best_match =
        Enum.max_by(pattern_weights, fn {pos, weight} ->
          if pos in pos_list, do: weight, else: 0.0
        end, fn -> {nil, 0.0} end)

      {matched_pos, weight} = best_match

      if matched_pos do
        {acc + weight, kw || word, dom_pos || matched_pos}
      else
        {acc, kw, dom_pos}
      end
    end)
  end
end

