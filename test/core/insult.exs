defmodule Core.IntentResolverInsultTest do
  use ExUnit.Case
  alias Core.{IntentResolver, SemanticInput}

  test "detects insult via profanity" do
IO.inspect({:profanity_hit?, Core.Profanity.hit?("fuck you")})
    sem = %SemanticInput{sentence: "fuck you", intent: :unknown, confidence: 0.0, token_structs: []}
    out = IntentResolver.resolve_intent(sem)
    assert out.intent == :insult
    assert out.confidence >= 1.0
    #assert out.source == :filter
  end
end

