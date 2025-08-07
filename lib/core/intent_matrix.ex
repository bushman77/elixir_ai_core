defmodule Core.IntentMatrix do
  @moduledoc """
  Scores token POS patterns to classify likely intent, keyword, and dominant POS.
  """

  @intent_patterns %{
    greeting: %{interjection: 1.0, noun: 0.5},
    command: %{verb: 1.0, noun: 0.3},
    question: %{wh: 1.0, verb: 0.7},
    affirmation: %{adverb: 1.0, adjective: 0.5},
    statement: %{noun: 0.6, verb: 0.4},
    why: %{wh: 0.9, verb: 0.5, noun: 0.3}
  }

  @doc """
  Classifies intent using weighted POS pattern matching.
  Returns: {intent, keyword, confidence, dominant_pos}
  """
def classify(tokens) when is_list(tokens) do
  tokens = Enum.filter(tokens, &is_struct(&1, Core.Token))

  scores =
    Enum.map(@intent_patterns, fn {intent, pattern_weights} ->
      {score, keyword, dom_pos} = score_tokens(tokens, pattern_weights)
      {intent, score, keyword, dom_pos}
    end)

  {intent, score, keyword, dom_pos} =
    Enum.max_by(scores, fn {_, s, _, _} -> s end, fn -> {:unknown, 0.0, nil, nil} end)

  %{
    intent: intent,
    confidence: score,
    keyword: keyword,
    dominant_pos: dom_pos
  }
end

  defp score_tokens(tokens, pattern_weights) do
    Enum.reduce(tokens, {0.0, nil, nil}, fn %Core.Token{text: word, pos: pos_list}, {acc, kw, dom_pos} ->
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

