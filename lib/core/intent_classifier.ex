defmodule Core.IntentClassifier do
  @moduledoc """
  Classifies user intent based on part-of-speech patterns, keyword boosts, and fallback logic.
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

  def classify(tokens) when is_list(tokens) do
    pattern_scores =
      for {intent, patterns} <- @patterns, reduce: %{} do
        acc ->
          match = Enum.any?(patterns, fn pat -> matches_pattern?(pat, tokens) end)
          if match, do: Map.put(acc, intent, @default_confidence), else: acc
      end

    keyword_scores =
      for {intent, keywords} <- @keyword_boosts, reduce: %{} do
        acc ->
          match = Enum.any?(tokens, fn %{word: word} -> word in keywords end)
          if match, do: Map.put(acc, intent, @boost_value), else: acc
      end

    combined_scores =
      Map.merge(pattern_scores, keyword_scores, fn _k, v1, v2 -> v1 + v2 end)

    fallback_intent =
      if combined_scores == %{},
        do: fallback(tokens),
        else: :none

    {best_intent, best_conf} =
      if fallback_intent != :none do
        {fallback_intent, 0.1}
      else
        combined_scores
        |> Enum.sort_by(fn {_k, v} -> -v end)
        |> List.first()
      end

    keyword = extract_keyword(tokens)

    source =
      cond do
        pattern_scores != %{} -> :pattern
        keyword_scores != %{} -> :keyword
        true -> :fallback
      end

    {:ok,
     %{
       intent: best_intent,
       confidence: Float.round(best_conf, 3),
       keyword: keyword,
       mood_hint: infer_mood(best_intent, tokens),
       fallback: best_intent == :unknown,
       source: source,
       pos_tags: Enum.map(tokens, & &1.pos),
       debug: %{
         base_confidences: pattern_scores,
         keyword_boosts: keyword_scores,
         combined_scores: combined_scores,
         patterns: @patterns[best_intent] || [],
         tokens: tokens
       }
     }}
  end

  defp matches_pattern?(pattern, tokens) do
    pos_list = Enum.map(tokens, & &1.pos)

    Enum.any?(0..(length(pos_list) - length(pattern)), fn offset ->
      Enum.slice(pos_list, offset, length(pattern)) == pattern
    end)
  end

  defp fallback(tokens) do
    if Enum.any?(tokens, fn %{pos: pos} -> pos in [:interjection, :noun] end) do
      :greeting
    else
      :unknown
    end
  end

  defp extract_keyword(tokens) do
    tokens
    |> Enum.filter(fn t -> t.pos in [:noun, :verb, :interjection, :adjective] end)
    |> Enum.map(& &1.word)
    |> List.first() || "that"
  end

  defp infer_mood(:greeting, _), do: :friendly
  defp infer_mood(:farewell, _), do: :reflective
  defp infer_mood(:affirmation, _), do: :positive
  defp infer_mood(:negation, _), do: :defensive
  defp infer_mood(_, _), do: :neutral
end

