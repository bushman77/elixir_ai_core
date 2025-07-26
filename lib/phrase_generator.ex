defmodule PhraseGenerator do
  @moduledoc """
  Generates a phrase by traversing BrainCell connections from a start word.
  Mood, intent, dopamine, and connection weight influence selection.
  Optionally sweetens the output for human-friendly interaction.
  """

  alias Brain
  alias BrainCell
  alias MoodCore
  alias Core.IntentMatrix

  @max_length 5

  @type mood ::
          :neutral | :reflective | :curious |
          :nostalgic | :happy | :sad

  @type intent ::
          :greeting | :question | :command | :inform |
          :reflect | :emote | :encourage | :why |
          :default

  @doc """
  Generates a phrase from a start word.

  ## Options
    - `:mood` - override current mood
    - `:intent` - guide selection toward relevant concepts
    - `:sweeten?` - if true, may inject a sweetener phrase

  Returns a generated phrase string.
  """
  def generate_phrase(start_word, opts \\ []) do
    mood = Keyword.get(opts, :mood, MoodCore.current_mood())
    intent = Keyword.get(opts, :intent, :default)
    sweeten? = Keyword.get(opts, :sweeten?, false)

    phrase =
      start_word
      |> do_generate(@max_length, [], mood, intent)
      |> Enum.reverse()
      |> Enum.join(" ")

    if sweeten?, do: maybe_sweeten(phrase, intent, mood), else: phrase
  end

  defp do_generate(_word, 0, acc, _mood, _intent), do: acc

  defp do_generate(word, length, acc, mood, intent) do
    case Brain.get(word) do
      %BrainCell{connections: [], word: actual_word} ->
        [actual_word | acc]

      %BrainCell{connections: conns, dopamine: dopa, word: actual_word} ->
        next_word =
          conns
          |> filter_by_intent(intent)
          |> mood_adjusted_sort(dopa, mood)
          |> List.first()
          |> then(& &1 && &1.target_id)

        if next_word do
          do_generate(next_word, length - 1, [actual_word | acc], mood, intent)
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

      # Higher score = more likely to be selected
      -1.0 * weight * dopa * mood_factor
    end)
  end

  defp filter_by_intent(conns, :default), do: conns

  defp filter_by_intent(conns, intent) do
    Enum.filter(conns, fn conn ->
      case Brain.get(conn.target_id) do
        %BrainCell{semantic_atoms: atoms} when is_list(atoms) ->
          IntentMatrix.relevant_to?(atoms, intent)

        _ ->
          true
      end
    end)
  end

  defp maybe_sweeten(phrase, intent, mood) do
    sweetener =
      case {intent, mood} do
        {:greeting, :happy} -> "– it's great to see you!"
        {:question, :curious} -> "🤔 what do you think?"
        {:reflect, :nostalgic} -> "…I often wonder about those moments."
        {:emote, :sad} -> "💙 you're not alone."
        {:encourage, :happy} -> "– keep going, you're doing great!"
        {:why, _} -> "– because meaning matters."
        _ -> ""
      end

    if sweetener == "" do
      phrase
    else
      phrase <> " " <> sweetener
    end
  end
end

