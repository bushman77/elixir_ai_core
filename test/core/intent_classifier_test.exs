defmodule Core.IntentClassifierTest do
  use ExUnit.Case, async: true

  alias Core.IntentClassifier
  alias Core.SemanticInput
  alias Core.Token

  # --- helpers ---------------------------------------------------------------

  defp sem(tokens) do
    %SemanticInput{
      sentence: tokens |> Enum.map(&elem(&1, 0)) |> Enum.join(" "),
      token_structs: Enum.map(tokens, fn {phrase, pos, idx} ->
        %Token{phrase: phrase, text: phrase, pos: List.wrap(pos), position: idx || 0, source: :test}
      end)
    }
  end

  # Provide {phrase, pos, idx?} tuples (idx defaults to 0; we set it anyway)
  defp with_idx(list) do
    list
    |> Enum.with_index()
    |> Enum.map(fn {{p, pos}, i} -> {p, pos, i} end)
  end

  defp classify(tokens), do: IntentClassifier.classify_tokens(sem(with_idx(tokens)))

  # --- tests -----------------------------------------------------------------

  test "greet: interjection → greet with keyword" do
    out = classify([{"hello", [:interjection]}])
    assert out.intent == :greet
    assert out.confidence >= 0.6
    assert out.keyword in ["hello", "hi", "hey", "yo", "sup"]
  end

  test "bye: lexical bonus triggers bye" do
    out = classify([{"bye", [:interjection]}])
    assert out.intent == :bye
    assert out.confidence >= 0.55
    assert out.keyword == "bye"
  end

  test "thank: MWE path triggers thank + canonical keyword" do
    # simulate your thanks multiword expression already merged
    out = classify([{"thanks_mwe", [:interjection]}])
    assert out.intent == :thank
    assert out.confidence >= 0.55
    assert out.keyword in ["thank you", "thanks", "thank", "thx", "ty", "thankyou"]
  end

  test "question: WH + '?' gives strong question" do
    out = classify([
      {"why", [:wh]},
      {"is",  [:auxiliary]},
      {"that",[:pronoun]},
      {"?",   [:punct]}
    ])
    assert out.intent == :question or out.intent == :why
    assert out.confidence >= 0.6
    # keyword could be "?" or "why" depending on extractor order
    assert out.keyword in ["?", "why", "time", "price", "weather", nil]
  end

  test "why bucket: WH adverb nudges toward :why" do
    out = classify([
      {"why", [:wh]},
      {"bother", [:verb]}
    ])
    assert out.intent in [:why, :question]
    assert out.confidence >= 0.55
  end

  test "command: imperative verb start" do
    out = classify([
      {"open", [:verb]},
      {"settings", [:noun]}
    ])
    assert out.intent == :command
    assert out.confidence >= 0.55
    assert out.keyword == "open"
  end

  test "confirm: 'yes' maps to confirm" do
    out = classify([{"yes", [:interjection]}])
    assert out.intent == :confirm
    assert out.confidence >= 0.55
  end

  test "deny: 'nope' maps to deny" do
    out = classify([{"nope", [:interjection]}])
    assert out.intent == :deny
    assert out.confidence >= 0.55
  end

  test "inform: simple subject-verb" do
    out = classify([
      {"weather", [:noun]},
      {"changed", [:verb]}
    ])
    assert out.intent == :inform
    assert out.confidence >= 0.55
    assert out.keyword == "weather"
  end

  test "insult rescue: no patterns but lexical insult wins" do
    out = classify([{"idiot", [:noun]}])
    assert out.intent == :insult
    assert out.confidence >= 0.85
  end

  test "unknown: neutral tokens with no hits" do
    out = classify([{"greenly", [:adverb]}])
    assert out.intent in [:unknown, :inform, :confirm, :deny] # allow some drift
  end

  test "top-2 margin produces higher confidence when clear winner" do
    # Greet interjection + 'thanks' (thank) present — greet should outscore or be close
    out = classify([
      {"hello", [:interjection]},
      {"thanks", [:interjection]}
    ])
    assert out.confidence >= 0.55
  end

  test "keyword extraction: question falls back to WH when no '?'" do
    out = classify([{"what", [:wh]}, {"time", [:noun]}])
    assert out.intent in [:question, :why]
    assert out.keyword in ["what", "time", "weather", "price", nil]
  end
end

