defmodule BrainOutput do
  @moduledoc """
  Builds an output string by walking from a starting cell through its connections.
  """

  alias Brain

  def top_words(starting_id \\ nil) do
    # If no word is given, pick the highest activated cell
    start_id =
      case starting_id do
        nil -> top_fired_cell_id()
        id -> id
      end

    case Brain.get(Brain, start_id) do
      nil -> "🤖 (no thoughts yet...)"
      cell -> walk_chain(cell)
    end
  end

  defp walk_chain(%{id: id, connections: []}), do: id

  defp walk_chain(%{id: id, connections: nil}), do: id

  defp walk_chain(%{id: id, connections: [next | _]}) do
    case Brain.get(Brain, next.target_id) do
      nil -> id
      next_cell -> id <> " " <> walk_chain(next_cell)
    end
  end

  def top_fired_cell_id do
    Brain.all_ids(Brain)
    |> Enum.map(&Brain.get(Brain, &1))
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
      case Brain.get(Brain, id) do
        %BrainCell{} = cell ->
          Brain.put(Brain, %{cell | activation: 0.0})

        _ ->
          :ok
      end
    end)
  end
end
