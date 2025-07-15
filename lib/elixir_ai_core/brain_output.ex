defmodule BrainOutput do
  @moduledoc """
  Handles AI output generation and external expression.
  Supports thought tracing, phrase generation, and mood expression.
  """

  alias Brain
  alias PhraseGenerator
  alias BrainCell

  # 🌟 Public API

  def say(message) when is_binary(message) do
    IO.puts("\n[🧠 AI] #{message}\n")
    {:reply, message}
  end

  def say_with_mood(message, mood) do
    tone =
      case mood do
        :happy -> "😄 "
        :sad -> "😞 "
        :excited -> "⚡ "
        :reflective -> "🌀 "
        :nostalgic -> "📸 "
        :curious -> "🤔 "
        _ -> ""
      end

    IO.puts("\n#{tone}[🧠 AI] #{message}\n")
    {:reply, message}
  end

  def say_top_words(starting_id \\ nil) do
    top_words(starting_id)
    |> say()
  end

  def thought_trace(word, mood \\ :reflective) do
    PhraseGenerator.generate_phrase(word, mood: mood)
    |> say_with_mood(mood)
  end

  # 🧠 Phrase via top firing cell

  def top_words(starting_id \\ nil) do
    start_id =
      case starting_id do
        nil -> top_fired_cell_id()
        id -> id
      end

    case Brain.get(start_id) do
      nil -> "🤖 (no thoughts yet...)"
      cell -> walk_chain(cell)
    end
  end

  # 🔁 Walk connections recursively

  defp walk_chain(%{id: id, connections: []}), do: id
  defp walk_chain(%{id: id, connections: nil}), do: id

  defp walk_chain(%{id: id, connections: [next | _]}) do
    case Brain.get(next.target_id) do
      nil -> id
      next_cell -> id <> " " <> walk_chain(next_cell)
    end
  end

  # 🔥 Activation Ranking

  def top_fired_cell_id do
    Brain.all_ids(Brain)
    |> Enum.map(&Brain.get(&1))
    |> Enum.filter(& &1)
    |> Enum.sort_by(& &1.activation, :desc)
    |> List.first()
    |> case do
      nil -> nil
      %BrainCell{id: id} -> id
    end
  end

  def reset_activations do
    Brain.all_ids(Brain)
    |> Enum.each(fn id ->
      case Brain.get(id) do
        %BrainCell{} = cell ->
          Brain.put(%{cell | activation: 0.0})

        _ -> :ok
      end
    end)
  end
end

