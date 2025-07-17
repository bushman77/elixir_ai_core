defmodule BrainCell.Supervisor do
  @moduledoc """
  DynamicSupervisor for managing BrainCell GenServers.
  Ensures they are started, monitored, and restarted if they crash.
  """

  use DynamicSupervisor

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a BrainCell process under dynamic supervision.
  Accepts a BrainCell struct or map.
  """
  def start_braincell(cell) do
    spec = %{
      id: cell.id,
      start: {BrainCell, :start_link, [cell]},
      restart: :transient,
      shutdown: 5000,
      type: :worker
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end

