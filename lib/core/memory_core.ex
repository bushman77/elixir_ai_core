defmodule Core.MemoryCore do
  use GenServer

  @moduledoc """
  MemoryCore stores short-term memory traces, including user inputs,
  intents, emotions, and activation metadata, enabling temporal continuity.
  """

  @memory_limit 20  # Number of recent memories to keep

  ## Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def remember(entry) when is_map(entry) do
    GenServer.cast(__MODULE__, {:remember, entry})
  end

  def recent(n \\ 5) do
    GenServer.call(__MODULE__, {:recent, n})
  end

  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  ## GenServer Callbacks

  def init(_) do
    {:ok, []}
  end

  def handle_cast({:remember, entry}, state) do
    timestamped = Map.put(entry, :timestamp, DateTime.utc_now())
    new_state = [timestamped | Enum.take(state, @memory_limit - 1)]
    {:noreply, new_state}
  end

  def handle_cast(:clear, _state) do
    {:noreply, []}
  end

  def handle_call({:recent, n}, _from, state) do
    {:reply, Enum.take(state, n), state}
  end
end

