defmodule Brain.Supervisor do
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_cell(cell_id) do
    spec = {BrainCell, cell_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
