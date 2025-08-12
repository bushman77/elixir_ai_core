defmodule ElixirAiCore.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Core.TaskSup},
      {Registry, keys: :unique, name: Core.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: BrainCellSupervisor},
      {ElixirAiCore.Supervisor, []}, # Assuming this is a custom supervisor
      {Brain, name: Brain},
      {Console, []}, # Assuming Console is a valid process module
      {Core.DB, []}, # Assuming Core.DB is a valid process module
      {Core.EmotionModulator, []}, # Assuming Core.EmotionModulator is a valid process module
      {MoodCore, []},
      {Brain.CuriosityThread, []},
      {Core.MemoryCore, []}, # Assuming Core.MemoryCore is a valid process module
      {Task, fn -> Core.MiniIntent.start() end}
    ]

    opts = [strategy: :one_for_one, name: ElixirAiCore.TopSupervisor]
    Supervisor.start_link(children, opts)
  end
end
