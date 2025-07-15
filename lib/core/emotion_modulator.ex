defmodule Core.EmotionModulator do
  @moduledoc """
  Maintains and adjusts the AI's emotional state over time.
  Tracks mood, dopamine, and serotonin levels for expression modulation.
  """

  use GenServer

  @type mood :: :neutral | :happy | :sad | :curious | :reflective | :excited | :nostalgic

  @valid_moods [:neutral, :happy, :sad, :curious, :reflective, :excited, :nostalgic]

  @default_state %{
    mood: :neutral,
    dopamine: 1.0,
    serotonin: 1.0,
    last_updated: nil
  }

  # --- Public API ---

  def start_link(_opts), do: GenServer.start_link(__MODULE__, @default_state, name: __MODULE__)

  def current_mood, do: GenServer.call(__MODULE__, :get_mood)
  def current_dopamine, do: GenServer.call(__MODULE__, :get_dopamine)
  def current_serotonin, do: GenServer.call(__MODULE__, :get_serotonin)

  def adjust_dopamine(delta), do: GenServer.cast(__MODULE__, {:adjust_dopamine, delta})
  def adjust_serotonin(delta), do: GenServer.cast(__MODULE__, {:adjust_serotonin, delta})

  def set_mood(mood) do
    if mood in @valid_moods do
      GenServer.cast(__MODULE__, {:set_mood, mood})
      {:ok, mood}
    else
      {:error, :invalid_mood}
    end
  end

  def moods, do: @valid_moods

  # --- GenServer Callbacks ---

  def init(state), do: {:ok, %{state | last_updated: now()}}

  def handle_call(:get_mood, _from, state), do: {:reply, state.mood, state}
  def handle_call(:get_dopamine, _from, state), do: {:reply, state.dopamine, state}
  def handle_call(:get_serotonin, _from, state), do: {:reply, state.serotonin, state}

  def handle_cast({:adjust_dopamine, delta}, state) do
    new_value = clamp(state.dopamine + delta)
    {:noreply, %{state | dopamine: new_value}}
  end

  def handle_cast({:adjust_serotonin, delta}, state) do
    new_value = clamp(state.serotonin + delta)
    {:noreply, %{state | serotonin: new_value}}
  end

  def handle_cast({:set_mood, mood}, state) do
    {:noreply, %{state | mood: mood, last_updated: now()}}
  end

  # --- Helpers ---

  defp now, do: DateTime.utc_now()
  defp clamp(val), do: max(0.0, min(val, 2.0))
end

