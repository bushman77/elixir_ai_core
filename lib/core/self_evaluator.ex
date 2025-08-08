defmodule Core.SelfEvaluator do
  @moduledoc """
  Evaluates AI outputs based on past inputs and symbolic context.
  Suggests improvement paths and flags weak responses.
  """

  alias Core.SemanticInput
  alias BrainOutput
  alias Core.IntentMatrix

  @type evaluation :: %{
          score: float(),
          reason: String.t(),
          suggested_action: String.t(),
          learning_goal: String.t() | nil
        }

  @doc """
  Evaluates a SemanticInput and BrainOutput pair.
  Returns a symbolic evaluation report.
  """
  def evaluate(%SemanticInput{} = input, %BrainOutput{} = output) do
    cond do
      output.phrase == nil or output.phrase == "" ->
        poor_output(input, "No phrase generated")

      input.confidence < 0.5 ->
        low_confidence(input, output)

      input.intent in ["unknown", nil] ->
        poor_output(input, "Unresolved intent")

      true ->
        good_output(input, output)
    end
  end

  defp poor_output(input, reason) do
    %{
      score: 0.2,
      reason: reason,
      suggested_action: "Ask LLM to generate examples for similar input",
      learning_goal: IntentMatrix.recommend_goal(input)
    }
  end

  defp low_confidence(input, output) do
    %{
      score: 0.4,
      reason: "Low confidence in intent match",
      suggested_action: "Add new intent patterns or enrich keyword boosts",
      learning_goal: "Study token patterns for '#{input.sentence}'"
    }
  end

  defp good_output(input, _output) do
    %{
      score: 0.9,
      reason: "Output acceptable",
      suggested_action: "Log successful pattern",
      learning_goal: nil
    }
  end
end

