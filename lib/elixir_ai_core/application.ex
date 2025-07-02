defmodule ElixirAiCore.Application do
    use Application

    def start(_type, _args) do
          children = [
                  {Registry, keys: :unique, name: BrainCell.Registry},
                  ElixirAiCore.Supervisor,          # <- this is your dynamic supervisor
                  {Brain, name: Brain}              # <- starts your DETS-based Brain
                ]

          opts = [strategy: :one_for_one, name: ElixirAiCore.TopSupervisor]
          Supervisor.start_link(children, opts)
        end
end

