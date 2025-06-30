defmodule ElixirAiCore.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Add workers here if needed
      {Registry, keys: :unique, name: BrainCell.Registry},
      BrainCell.Supervisor
    ]

    opts = [strategy: :one_for_one, name: ElixirAiCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
