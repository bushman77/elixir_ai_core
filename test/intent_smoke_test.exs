defmodule IntentSmokeTest do
  use ExUnit.Case
  alias Core.{SemanticInput, Tokenizer, POSEngine, IntentClassifier, ResponsePlanner}

  defp run(sent) do
    %SemanticInput{sentence: sent, source: :user}
    |> Tokenizer.tokenize()
    |> POSEngine.tag()
    |> IntentClassifier.classify_tokens()
    |> ResponsePlanner.analyze()
  end

@cases [
  {"hello there", :greeting},
  {"good morning", :greeting},
  {"thank you", :thank},
  {"what time is it", :question},
  {"how much is that", :question},
  {"fuck you", :insult}
]

test "baseline intents" do
  for {sent, expected} <- @cases do
    out = run(sent)
    assert out.intent == expected,
           "#{sent} -> #{out.intent} (kw=#{inspect out.keyword} conf=#{out.confidence})"
  end
end

end

