defmodule ElixirAiCore.SentenceIntentTest do
  use ExUnit.Case
  alias ElixirAiCore.SentenceIntent

  describe "intent_from_pos/1" do
    test "detects basic 'How are you' as a question" do
      assert SentenceIntent.intent_from_pos([:adverb, :verb, :pronoun]) == :question
    end

    test "detects 'Who is she' structure" do
      assert SentenceIntent.intent_from_pos([:wh_pronoun, :verb, :noun]) == :question
    end

    test "detects 'Can you swim?' as a question" do
      assert SentenceIntent.intent_from_pos([:aux, :pronoun, :verb]) == :question
    end

    test "detects 'What time is it?' form" do
      assert SentenceIntent.intent_from_pos([:wh_determiner, :noun, :verb]) == :question
    end

    test "returns :unknown for unrecognized patterns" do
      assert SentenceIntent.intent_from_pos([:noun, :verb, :noun]) == :unknown
    end
  end
end
