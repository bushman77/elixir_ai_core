defmodule Core.CognitionManager do
  @moduledoc """
  Orchestrates input processing, mood, memory, and response planning
  to generate context-aware, emotionally intelligent replies.
  """

  alias Core.{MemoryCore, MoodCore, ResponsePlanner}
  alias Core.IntentClassifier

  def handle_input(text) when is_binary(text) do
    # Step 1: Analyze input for intent and keyword
    classification = IntentClassifier.classify(text)

    # Step 2: Remember input + classification
    MemoryCore.remember(%{
      text: text,
      intent: classification.intent,
      keyword: Map.get(classification, :keyword),
      mood: MoodCore.current_mood()
    })

    # Step 3: Get current mood
    mood = MoodCore.current_mood()

    # Step 4: Plan response with mood awareness
    response =
      classification
      |> Map.put(:mood, mood)
      |> ResponsePlanner.plan()

    # Step 5: Mood reinforcement example (customize as needed)
    reinforce_mood_based_on_intent(classification.intent)

    {:ok, response}
  end

  defp reinforce_mood_based_on_intent(:greeting), do: MoodCore.reinforce(:happy, 0.3)
  defp reinforce_mood_based_on_intent(:question), do: MoodCore.reinforce(:curious, 0.4)
  defp reinforce_mood_based_on_intent(:reflect), do: MoodCore.reinforce(:reflective, 0.5)
  defp reinforce_mood_based_on_intent(:recall), do: MoodCore.reinforce(:nostalgic, 0.5)
  defp reinforce_mood_based_on_intent(_), do: :ok
end

