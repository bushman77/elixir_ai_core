defmodule IntentRegressionTest do
  use ExUnit.Case, async: true
  alias Core.{IntentClassifier, SemanticInput}

  test "hello → greet without tokens" do
    sem = %SemanticInput{sentence: "hello", token_structs: []}
    out = IntentClassifier.classify(sem)
    assert out.intent == :greet
  end

  test "hello there → greet without tokens" do
    sem = %SemanticInput{sentence: "hello there", token_structs: []}
    out = IntentClassifier.classify(sem)
    assert out.intent == :greet
  end
end

