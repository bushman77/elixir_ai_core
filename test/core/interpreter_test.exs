defmodule Core.InterpreterTest do
  use ExUnit.Case

  test "interprets a modal question with 'you' as subject" do
    input = %{
      type: :question,
      intent: :can_subject_do_action,
      subject: "you",
      verb: "jump"
    }

    assert Core.Interpreter.interpret(input) == "🤖 Yes, I can jump!"
  end

  test "interprets a modal question with unknown subject" do
    input = %{
      type: :question,
      intent: :can_subject_do_action,
      subject: "she",
      verb: "fly"
    }

    assert Core.Interpreter.interpret(input) ==
             "🤖 I'm not sure who you're asking to fly, but sounds fun!"
  end
end
