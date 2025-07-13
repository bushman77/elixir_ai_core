defmodule ElixirAiCore.SentenceIntentTest do
  use ExUnit.Case
  alias SentenceIntent

  describe "intent_from_word_pos_list/1" do
    test "recognizes greeting from pattern" do
      pos_list = [[{"Hello", :interjection}]]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :greeting
    end

    test "recognizes greeting from fallback word" do
      pos_list = [[{"Hi", :unknown}]]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :greeting
    end

    test "recognizes question pattern" do
      pos_list = [[{"What", :wh_pronoun}], [{"is", :verb}], [{"this", :noun}]]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :question
    end

    test "recognizes command pattern" do
      pos_list = [[{"Go", :verb}], [{"home", :noun}]]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :command
    end

    test "recognizes exclamation pattern" do
      pos_list = [[{"Wow", :interjection}], [{"!", :exclamation}]]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :exclamation
    end

    test "recognizes negation pattern" do
      pos_list = [
        [{"I", :pronoun}],
        [{"do", :aux}],
        [{"not", :negation}],
        [{"want", :verb}]
      ]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :negation
    end

    test "recognizes request pattern" do
      pos_list = [
        [{"Could", :modal}],
        [{"you", :pronoun}],
        [{"help", :verb}]
      ]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :request
    end

    test "recognizes affirmation from pattern" do
      pos_list = [[{"Yes", :affirmative}]]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :affirmation
    end

    test "recognizes affirmation from fallback word" do
      pos_list = [[{"Yeah", :unknown}]]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :affirmation
    end

    test "recognizes statement from pattern" do
      pos_list = [
        [{"The", :determiner}],
        [{"cat", :noun}],
        [{"sleeps", :verb}]
      ]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :statement
    end

    test "returns :unknown for unmatched input" do
      pos_list = [
        [{"Blue", :adjective}],
        [{"stars", :noun}],
        [{"everywhere", :adverb}]
      ]
      assert SentenceIntent.intent_from_word_pos_list(pos_list) == :unknown
    end
  end
end

