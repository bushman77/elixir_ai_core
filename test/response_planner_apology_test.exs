defmodule Core.ResponsePlannerApologyTest do
  use ExUnit.Case, async: false

  alias Core.ResponsePlanner
  alias Core.SemanticInput

  # Clean the per-process flags between tests
  setup do
    Process.delete(:forgive_until)
    Process.delete(:planner_dbg)
    :ok
  end

  defp sem(sentence, intent \\ :unknown, opts \\ []) do
    mood       = Keyword.get(opts, :mood, :grumpy)
    keyword    = Keyword.get(opts, :keyword, nil)
    confidence = Keyword.get(opts, :confidence, 0.0)

    %SemanticInput{
      sentence: sentence,
      intent: intent,
      keyword: keyword,
      confidence: confidence,
      mood: mood
    }
  end

  @positive_greeting_markers [
    "Great to see you",
    "pumped to help",
    "Ready when you are"
  ]

  test "apology short-circuits and sets forgiveness window" do
    # 1) User apologizes
    s1 = sem("my bad—won’t happen again", :unknown, mood: :grumpy)
         |> ResponsePlanner.analyze()

    assert is_binary(s1.response)
    assert s1.response =~ "We’re good" or
           s1.response =~ "Thanks for saying that" or
           s1.response =~ "Thanks for the apology"

    # 2) Immediately greeting should be overtly positive (forgiveness window)
    s2 = sem("hello there", :greeting, keyword: "hello", confidence: 0.7, mood: :grumpy)
         |> ResponsePlanner.analyze()

    assert Enum.any?(@positive_greeting_markers, &String.contains?(s2.response, &1)),
           "expected a positive greeting after apology, got: #{s2.response}"

    # 3) An insult inside the forgiveness window should de-escalate
    s3 = sem("fuck off", :insult, confidence: 1.0, mood: :grumpy)
         |> ResponsePlanner.analyze()

    assert s3.response =~ "We just reset—let’s keep it productive",
           "expected de-escalated boundary during forgiveness, got: #{s3.response}"

    # 4) Debug trace should show we’re inside forgiveness during step (2) or (3)
    assert is_map(s3.activation_summary)
    assert Map.has_key?(s3.activation_summary, :forgiven?)
    assert s3.activation_summary.forgiven? == true
  end

  test "matrix-provided :apology works even without a sentence" do
    s = %SemanticInput{
      sentence: nil,
      intent: :apology,
      keyword: nil,
      confidence: 0.9,
      mood: :negative
    }
    |> ResponsePlanner.analyze()

    assert is_binary(s.response)
    assert s.response =~ "Thanks for saying that" or s.response =~ "We’re good"
  end
end

