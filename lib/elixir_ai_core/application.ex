defmodule ElixirAiCore.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: BrainCell.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: BrainCellSupervisor},
      ElixirAiCore.Supervisor,
      {Brain, name: Brain},
      Console,    # your GenServer Console process
      Core.DB
    ]

    opts = [strategy: :one_for_one, name: ElixirAiCore.TopSupervisor]
    Supervisor.start_link(children, opts)
  end
end

