defmodule Core.IntentMatrixApologyTest do
  use ExUnit.Case, async: true

  alias Core.IntentMatrix

  # Build lightweight "tokens" (not Core.Token structs) that work with score/1
  defp toks(str) do
    str
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&%{text: &1, pos: []})
  end

  test "apology via bigram: 'my bad'" do
    {intent, conf} = IntentMatrix.score(toks("my bad"))
    assert intent == :apology
    assert conf >= 0.5
  end

  test "apology via bigram: 'excuse me'" do
    {intent, conf} = IntentMatrix.score(toks("excuse me"))
    assert intent == :apology
    assert conf >= 0.5
  end

  test "apology via morphology: 'I apologize for that'" do
    {intent, conf} = IntentMatrix.score(toks("I apologize for that"))
    assert intent == :apology
    assert conf >= 0.5
  end

  test "apology via morphology: 'we apologise for the delay'" do
    {intent, conf} = IntentMatrix.score(toks("we apologise for the delay"))
    assert intent == :apology
    assert conf >= 0.5
  end

  test "apology via morphology: 'my apologies'" do
    {intent, conf} = IntentMatrix.score(toks("my apologies"))
    assert intent == :apology
    assert conf >= 0.5
  end

  test "non-apology phrase should not hit apology rule" do
    {intent, _conf} = IntentMatrix.score(toks("how much is this price"))
    refute intent == :apology
  end
end

