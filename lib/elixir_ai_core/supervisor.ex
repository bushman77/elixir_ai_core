defmodule ElixirAiCore.Supervisor do
  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Ensures a BrainCell with the given ID is running.
  If already running, returns {:ok, pid}.
  Otherwise, starts a new one and returns {:ok, pid}.
  """
  def ensure_started(%{id: id, type: type} = args) do
    case Registry.lookup(BrainCellRegistry, id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        spec = %{
          id: BrainCell,
          start: {BrainCell, :start_link, [args]},
          restart: :transient,
          type: :worker
        }

        DynamicSupervisor.start_child(__MODULE__, spec)
    end
  end
end
