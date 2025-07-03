defmodule ElixirAiCore.Supervisor do
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_braincell(id, type \\ :generic) do
    spec = %{
      id: BrainCell,
      start: {BrainCell, :start_link, [%{id: id, type: type}]},
      restart: :transient,
      type: :worker
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
