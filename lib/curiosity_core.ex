defmodule CuriosityCore do
  @moduledoc """
  The system responsible for generating self-initiated questions and exploration drives.
  """

  def scan_and_ponder(input_context, brain_state) do
    input_context
    |> detect_novelty(brain_state)
    |> generate_question()
  end

  defp detect_novelty(context, brain_state) do
    # Compares incoming tokens, meaning, or themes against memory
    Enum.filter(context, fn token ->
      not Brain.known_concept?(token.word)
    end)
  end

  defp generate_question(novel_words) do
    Enum.map(novel_words, fn word ->
      "What does '#{word}' really mean?"
    end)
  end
end

