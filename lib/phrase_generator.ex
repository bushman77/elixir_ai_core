defmodule PhraseGenerator do
  @moduledoc """
  Generates a phrase starting from a word by walking brain cell connections.
  Traversal is influenced by connection weight, mood, and dopamine levels.
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
  Optionally accepts `mood`; if not provided, uses current mood.
  """
  def generate_phrase(start_word, opts \\ []) do
    mood = Keyword.get(opts, :mood, MoodCore.current_mood())
    do_generate(start_word, @max_length, [], mood)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp do_generate(_word, 0, acc, _mood), do: acc

  defp do_generate(word, length, acc, mood) do
    case Brain.get(word) do
      nil ->
        acc

      %BrainCell{connections: []} ->
        [word | acc]

      %BrainCell{connections: conns, dopamine: dopa} ->
        next_word =
          conns
          |> mood_adjusted_sort(dopa, mood)
          |> List.first()
          |> Map.get(:target_id)

        do_generate(next_word, length - 1, [word | acc], mood)
    end
  end

  defp mood_adjusted_sort(conns, dopa, mood) do
    Enum.sort_by(conns, fn conn ->
      weight = conn.weight || 1.0
      dopa = dopa || 1.0

      mood_factor =
        case mood do
          :happy -> 1.2
          :sad -> 0.8
          :curious -> 0.7 + :rand.uniform() * 0.6
          :reflective -> 1.0
          :nostalgic -> 0.9
          _ -> 1.0
        end

      adjusted = weight * dopa * mood_factor
      -adjusted
    end)
  end
end

