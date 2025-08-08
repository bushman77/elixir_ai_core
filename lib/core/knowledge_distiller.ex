defmodule Core.KnowledgeDistiller do
  @moduledoc """
  Distills new symbolic knowledge from introspective prompts.
  Converts output into BrainCells, phrases, or goals.
  """

  alias Core.SemanticInput
  alias Brain
  alias BrainCell

  @type distilled_knowledge :: %{
          new_cells: list(BrainCell.t()),
          new_phrases: list(String.t()),
          summary: String.t()
        }

  @doc """
  Generates a symbolic enrichment plan based on evaluation.
  Assumes external call to LLM or future learning core.
  """
  def distill(%SemanticInput{} = input, %{reason: reason, learning_goal: goal}) do
    prompt = build_prompt(input, reason, goal)

    # 🧠 Simulated LLM call (in real use, connect this to your LLM client or offline enrich DB)
    response = simulate_llm_response(prompt)

    %{
      new_cells: build_braincells(response),
      new_phrases: extract_phrases(response),
      summary: "Distilled from: #{reason}"
    }
  end

  defp build_prompt(input, reason, goal) do
    """
    The system failed to respond well to this sentence: "#{input.sentence}"
    Reason: #{reason}
    Goal: #{goal}

    Suggest key concepts, POS patterns, and phrase examples to encode as symbolic knowledge.
    """
  end

  defp simulate_llm_response(prompt) do
    IO.puts("[Simulated LLM prompt]:\n" <> prompt)

    %{
      concepts: ["vivid metaphor", "sarcasm detection"],
      pos_patterns: [["ADV", "ADJ"], ["NOUN", "VERB", "NOUN"]],
      examples: ["like a rocket on fire", "you nailed it again, Sherlock"],
      definitions: ["Metaphors map abstract ideas onto concrete experiences."]
    }
  end

  defp build_braincells(%{concepts: concepts, definitions: defs}) do
    Enum.zip(concepts, defs)
    |> Enum.map(fn {concept, defn} ->
      %BrainCell{
        word: concept,
        pos: [:noun],
        definition: defn,
        type: :concept,
        activation: 0.0
      }
    end)
  end

  defp extract_phrases(%{examples: exs}), do: exs
end

