defmodule ElixirAiCore.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: BrainCell.Registry},
      ElixirAiCore.Supervisor,
      {Brain, name: Brain}
    ]

    opts = [strategy: :one_for_one, name: ElixirAiCore.TopSupervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # 🧠 Launch ConsoleInterface in a separate task after boot
    Task.start(fn ->
      # Optional: wait for the system to boot up fully
      Process.sleep(500)
      ElixirAiCore.ConsoleInterface.start()
    end)

    {:ok, pid}
  end
end
