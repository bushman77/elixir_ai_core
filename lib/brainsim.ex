defmodule BrainSim do
  @moduledoc "Simulates signal propagation between BrainCells."

  @max_depth 10

  def fire(cell, all_cells, strength \\ 1.0, max_depth \\ 5, visited \\ MapSet.new()) do
    if max_depth <= 0 or MapSet.member?(visited, cell.id) or strength < 0.01 do
      all_cells
    else
      visited = MapSet.put(visited, cell.id)

      IO.puts("🔥 Firing cell #{cell.id} at strength #{Float.round(strength, 3)}")

      Enum.reduce(cell.connections, all_cells, fn conn, acc_cells ->
        updated_cells =
          case Enum.find(acc_cells, fn c -> c.id == conn.target_id end) do
            nil ->
              acc_cells

            target_cell ->
              new_strength = strength * conn.weight
              IO.puts(" → Sending to #{conn.target_id} (w=#{conn.weight}, d=#{conn.delay_ms}ms)")
              updated_target = %{target_cell | activation: target_cell.activation + new_strength}

              # Replace updated target in list
              updated_cells =
                List.replace_at(
                  acc_cells,
                  Enum.find_index(acc_cells, fn c -> c.id == updated_target.id end),
                  updated_target
                )

              fire(updated_target, updated_cells, new_strength, max_depth - 1, visited)
          end

        updated_cells
      end)
    end
  end

  defp do_fire(%BCell{id: id, connections: connections}, strength, depth, visited, trail) do
    if depth >= @max_depth or strength <= 0.01 or MapSet.member?(visited, id) do
      {visited, trail}
    else
      IO.puts("🔥 Firing cell #{id} with strength #{Float.round(strength, 2)}")

      visited = MapSet.put(visited, id)
      trail = trail ++ [id]

      Enum.reduce(connections, {visited, trail}, fn conn, {v, t} ->
        Process.sleep(conn.delay_ms)

        case Brain.get(conn.target_id) do
          %BCell{} = target_cell ->
            do_fire(target_cell, strength * conn.weight, depth + 1, v, t)

          _ ->
            {v, t}
        end
      end)
    end
  end
end
