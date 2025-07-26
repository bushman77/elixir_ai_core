defmodule Core.IntentClassifierTest do
  use ExUnit.Case, async: true

  alias Core.IntentClassifier

  describe "intent classification with keyword boosts" do
    test "recognizes greeting with 'hello' keyword boost" do
      tokens = [
        %{word: "Hello", pos: [:interjection]}
      ]

      {:ok, result} = IntentClassifier.classify(tokens)
      assert result.intent == :greeting
      assert result.confidence > 0.2
      assert result.keyword == "Hello"
    end

    test "boosts request intent with 'please'" do
      tokens = [
        %{word: "Please", pos: [:adverb]},
        %{word: "help", pos: [:verb]},
        %{word: "me", pos: [:pronoun]}
      ]

      {:ok, result} = IntentClassifier.classify(tokens)
      assert result.intent == :request
      assert result.confidence > 0.3
      assert result.keyword == "Please"
    end

    test "detects negation intent boosted by 'no'" do
      tokens = [
        %{word: "No", pos: [:adverb]},
        %{word: "thank", pos: [:verb]},
        %{word: "you", pos: [:pronoun]}
      ]

      {:ok, result} = IntentClassifier.classify(tokens)
      assert result.intent == :negation
      assert result.confidence > 0.3
      assert result.keyword == "No"
    end

    test "falls back to :unknown when no pattern or keyword matches" do
      tokens = [
        %{word: "Blorf", pos: [:noun]}
      ]

      {:ok, result} = IntentClassifier.classify(tokens)

IO.inspect result
      assert result.intent == :unknown
      assert result.confidence == 0.0
      assert result.keyword == "Blorf"
    end

    test "combines base confidence and keyword boosts correctly" do
      tokens = [
        %{word: "Hi", pos: [:interjection]},
        %{word: "there", pos: [:pronoun]}
      ]

      {:ok, result} = IntentClassifier.classify(tokens)
      # :greeting pattern plus "hi" keyword boost
      assert result.intent == :greeting
      assert result.confidence > 0.3
      assert result.keyword == "Hi"
    end
  end
end

