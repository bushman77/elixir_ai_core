# lib/brain_cell/supervisor.ex
defmodule BrainCell.Supervisor do
  use DynamicSupervisor

  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  def start_cell(id), do: DynamicSupervisor.start_child(__MODULE__, {BrainCell, id})

  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)
end
