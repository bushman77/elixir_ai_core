defmodule BrainSim do
  @moduledoc """
  Simulates signal propagation between BrainCells based on spatial distance and connection weight.
  """

  alias BrainCell

  @doc """
  Fires a signal from a brain cell. Activates all connected cells based on weight and delay.
  """
  def fire(cell, all_cells, strength \\ 1.0, max_depth \\ 3, visited \\ MapSet.new()) do
    IO.puts("Firing from cell #{cell.id} with strength #{Float.round(strength, 3)}")

    # Mark current cell as visited
    visited = MapSet.put(visited, cell.id)

    Enum.reduce(cell.connections, all_cells, fn conn, acc_cells ->
      if MapSet.member?(visited, conn.target_id) or max_depth <= 0 do
        acc_cells
      else
        # Apply weight to signal strength
        new_strength = strength * conn.weight

        # Simulate delay (just a print message — no actual sleep for now)
        IO.puts(
          " → Sending to cell #{conn.target_id} (delay #{conn.delay_ms}ms, weight #{Float.round(conn.weight, 3)})"
        )

        # Find the target cell
        case Enum.find(acc_cells, fn c -> c.id == conn.target_id end) do
          nil ->
            acc_cells

          target_cell ->
            updated_target = %{target_cell | activation: target_cell.activation + new_strength}

            # Recursive fire to next layer
            updated_cells =
              List.replace_at(
                acc_cells,
                Enum.find_index(acc_cells, fn c -> c.id == updated_target.id end),
                updated_target
              )

            fire(updated_target, updated_cells, new_strength, max_depth - 1, visited)
        end
      end
    end)
  end
end
