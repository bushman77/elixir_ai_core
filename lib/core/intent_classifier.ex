defmodule Core.IntentClassifier do
  @moduledoc """
  Classifies user intent based on part-of-speech patterns and keyword boosts.
  """

  @patterns %{
    greeting: [[:interjection], [:interjection, :pronoun], [:interjection, :verb]],
    farewell: [[:farewell], [:verb, :farewell], [:noun, :farewell]],
    question: [[:wh_adverb, :verb], [:verb, :pronoun], [:modal, :pronoun, :verb]],
    command: [[:verb], [:verb, :determiner, :noun]],
    affirmation: [[:interjection], [:adverb, :adjective], [:verb, :determiner]],
    negation: [[:adverb, :verb], [:interjection, :verb]]
  }

  @keyword_boosts %{
    greeting: ~w(hello hi hey sup howdy greetings yo),
    farewell: ~w(bye goodbye later cya farewell adieu),
    question: ~w(what when where why how who whose which),
    command: ~w(go stop get bring take open close run show give),
    affirmation: ~w(yes yeah sure definitely ok okay absolutely indeed),
    negation: ~w(no not never nope nah don't won't can't shouldn't)
  }

  @default_confidence 0.4
  @boost_value 0.3
  @threshold 0.5

  @doc """
  Returns a map with `:intent`, `:confidence`, `:keyword`, and `:dominant_pos`.
  """
  def classify(tokens) when is_list(tokens) do
IO.inspect Brain.get_state
    base_scores =
      Enum.map(@patterns, fn {intent, patterns} ->
        matched = Enum.any?(patterns, &matches_pattern?(&1, tokens))
        score = if matched, do: @default_confidence, else: 0.0
        {intent, score}
      end)

    boosted_scores =
      Enum.map(base_scores, fn {intent, score} ->
        boost = boost_from_keywords(intent, tokens)
        {intent, score + boost}
      end)

    {best_intent, best_score} =
      Enum.max_by(boosted_scores, fn {_intent, score} -> score end, fn -> {:unknown, 0.0} end)

    keyword = extract_keyword(tokens)
    dominant_pos = extract_dominant_pos(tokens)

    if best_score >= @threshold do
      %{
        intent: best_intent,
        confidence: best_score,
        keyword: keyword,
        dominant_pos: dominant_pos
      }
    else
      %{
        intent: :unknown,
        confidence: best_score,
        keyword: keyword,
        dominant_pos: dominant_pos
      }
    end
  end

  defp matches_pattern?(pattern, tokens) do
    pos_list = Enum.map(tokens, & &1.pos)
    Enum.any?(0..(length(pos_list) - length(pattern)), fn offset ->
      Enum.slice(pos_list, offset, length(pattern)) == pattern
    end)
  end

  defp boost_from_keywords(intent, tokens) do
    words = Enum.map(tokens, & &1.word)
    boost =
      Enum.any?(words, fn word ->
        String.downcase(word) in Map.get(@keyword_boosts, intent, [])
      end)

    if boost, do: @boost_value, else: 0.0
  end

  defp extract_keyword(tokens) do
    tokens
    |> Enum.find(fn t -> t.pos in [:noun, :verb, :interjection, :adjective] end)
    |> case do
      nil -> "that"
      token -> token.word
    end
  end

  defp extract_dominant_pos(tokens) do
    tokens
    |> Enum.flat_map(&List.wrap(&1.pos))
    |> Enum.frequencies()
    |> Enum.max_by(fn {_pos, count} -> count end, fn -> {:unknown, 0} end)
    |> elem(0)
  end
end

