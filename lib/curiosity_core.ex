defmodule CuriosityCore do
  @moduledoc """
  Generates questions about novel concepts and registers them for exploration.
  """

  alias Brain.CuriosityThread

  # Public entry point
  def scan_and_ponder(input_context, brain_state) do
    novel_tokens = detect_novelty(input_context, brain_state)

    Enum.each(novel_tokens, fn token ->
      CuriosityThread.register_activation(token.word)
    end)

    generate_questions(novel_tokens)
  end

  # Detects words that are new or unexpected in the current brain state
  defp detect_novelty(context, brain_state) do
    Enum.filter(context, fn token ->
      not Brain.known_concept?(token.word) or unexpected_combination?(token, brain_state)
    end)
  end

  # Placeholder for now; expand with real novelty logic later
  defp unexpected_combination?(_token, _brain_state), do: false

  # Generates natural questions based on novelty and POS
  defp generate_questions(novel_tokens) do
    Enum.flat_map(novel_tokens, fn %{word: word, pos: pos} = token ->
      templates_for(pos)
      |> Enum.map(&fill_template(&1, word))
    end)
  end

  # Templates vary depending on the part of speech
  defp templates_for("noun"), do: [
    "What is %{word}?",
    "How does %{word} relate to other things I know?",
    "Why is %{word} important?"
  ]

  defp templates_for("verb"), do: [
    "How do people typically %{word}?",
    "When do you usually %{word}?",
    "What happens if you don't %{word}?"
  ]

  defp templates_for(_), do: [
    "What does %{word} really mean?"
  ]

  # Simple variable interpolation
  defp fill_template(template, word) do
    String.replace(template, "%{word}", word)
  end
end

