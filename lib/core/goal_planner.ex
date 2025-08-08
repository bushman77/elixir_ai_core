defmodule Core.GoalPlanner do
  @moduledoc """
  Manages introspective goals for symbolic improvement.
  Tracks and prioritizes AI's learning tasks.
  """

  use GenServer

  @type goal :: %{
          id: binary(),
          title: String.t(),
          reason: String.t(),
          priority: integer(),
          status: :new | :in_progress | :done
        }

  @impl true
  def init(_), do: {:ok, []}

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def add_goal(title, reason, priority \\ 1) do
    GenServer.cast(__MODULE__, {:add_goal, title, reason, priority})
  end

  def list_goals(), do: GenServer.call(__MODULE__, :list)

  def complete_goal(id), do: GenServer.cast(__MODULE__, {:complete, id})

  @impl true
  def handle_call(:list, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:add_goal, title, reason, priority}, state) do
    goal = %{
      id: UUID.uuid4(),
      title: title,
      reason: reason,
      priority: priority,
      status: :new
    }

    {:noreply, [goal | state]}
  end

  @impl true
  def handle_cast({:complete, id}, state) do
    new_state =
      Enum.map(state, fn
        %{id: ^id} = g -> %{g | status: :done}
        g -> g
      end)

    {:noreply, new_state}
  end
end

