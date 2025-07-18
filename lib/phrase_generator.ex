defmodule PhraseGenerator do
  @moduledoc """
  Generates a phrase by traversing BrainCell connections from a start word.
  Mood, dopamine, and connection weight influence selection.
  """

  alias Brain
  alias BrainCell
  alias MoodCore

  @max_length 5

  @type mood ::
          :neutral | :reflective | :curious |
          :nostalgic | :happy | :sad

  @doc """
  Generates a phrase from a start word.
  Accepts optional `mood`; defaults to current mood from MoodCore.
  """
  def generate_phrase(start_word, opts \\ []) do
    mood = Keyword.get(opts, :mood, MoodCore.current_mood())

    start_word
    |> do_generate(@max_length, [], mood)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp do_generate(_word, 0, acc, _mood), do: acc

  defp do_generate(word, length, acc, mood) do
    case Brain.get(word) do
      %BrainCell{connections: [], word: actual_word} ->
        [actual_word | acc]

      %BrainCell{connections: conns, dopamine: dopa, word: actual_word} ->
        next_word =
          conns
          |> mood_adjusted_sort(dopa, mood)
          |> List.first()
          |> then(& &1 && &1.target_id)

        if next_word do
          do_generate(next_word, length - 1, [actual_word | acc], mood)
        else
          [actual_word | acc]
        end

      _ ->
        acc
    end
  end

  defp mood_adjusted_sort(conns, dopa, mood) do
    dopa = dopa || 1.0

    Enum.sort_by(conns, fn conn ->
      weight = conn.weight || 1.0

      mood_factor =
        case mood do
          :happy -> 1.2
          :sad -> 0.8
          :curious -> 0.7 + :rand.uniform() * 0.6
          :reflective -> 1.0
          :nostalgic -> 0.9
          _ -> 1.0
        end

      # Higher score = more likely to be first
      -1.0 * weight * dopa * mood_factor
    end)
  end
end

