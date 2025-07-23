defmodule ElixirAiCore.BrainTrainer do
  alias Brain
  alias BrainCell

  def teach_chain(words) when is_list(words) do
    words
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [from, to] ->
      # Start the brain cells if they don't exist
      ElixirAiCore.Supervisor.start_braincell(from, :word)
      ElixirAiCore.Supervisor.start_braincell(to, :word)

      # Get the current state
      from_cell = BrainCell.state(from)

      # Update connections
      updated_from = %BrainCell{
        from_cell
        | connections: [%{target_id: to, weight: 1.0, delay_ms: 100}]
      }

      # Save updated cell
      GenServer.cast(
        {:via, Registry, {Core.Registry, from}},
        {:update_connections, updated_from.connections}
      )
    end)

    :ok
  end
end
