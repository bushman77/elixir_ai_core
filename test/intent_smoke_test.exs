defmodule IntentSmokeTest do
  use ExUnit.Case, async: true

  alias Core.{
    SemanticInput,
    Tokenizer,
    POSEngine,
    IntentClassifier,
    ResponsePlanner
  }

  # End-to-end helper: sentence -> tokens -> POS -> classify -> analyze
  defp run(sent) do
    %SemanticInput{sentence: sent, source: :user}
    |> Tokenizer.tokenize()
    |> POSEngine.tag()
    |> IntentClassifier.classify_tokens()
    |> ResponsePlanner.analyze()
  end

  # Allow small, real-world drift in labels (:greet vs :greeting; thanks may map to greeting)
  @cases [
    {"hello there",         [:greet, :greeting]},
    {"good morning",        [:greet, :greeting]},
    {"thank you",           [:thank, :greet, :greeting]},
    {"what time is it",     [:question, :why]},
    {"how much is that",    [:question]},
    {"fuck you",            [:insult]}
  ]

  test "baseline intents" do
    Enum.each(@cases, fn {sent, allowed} ->
      out = run(sent)

      assert out.intent in allowed,
             """
             #{inspect(sent)} -> unexpected intent: #{inspect(out.intent)}
               keyword:    #{inspect(out.keyword)}
               confidence: #{inspect(out.confidence)}
               allowed:    #{inspect(allowed)}
             """
      assert is_number(out.confidence) and out.confidence >= 0.5
    end)
  end
end

