defmodule MoodCore do
  use GenServer

  @moduledoc """
  MoodCore tracks the evolving emotional state of the system, influenced by
  dopamine and serotonin levels from active BrainCells. Mood intensities decay
  over time toward neutrality unless reinforced.
  """

  @moods [:happy, :excited, :sad, :nostalgic, :reflective, :neutral]
  @decay_rate 0.005

  ## Public API

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Returns the current dominant mood (the highest-intensity one)."
  def current_mood, do: GenServer.call(__MODULE__, :current_mood)

  @doc "Returns the intensity of a given mood (0.0 to 1.0)."
  def mood_score(mood), do: GenServer.call(__MODULE__, {:mood_score, mood})

  @doc "Registers neurotransmitter levels from a firing BrainCell."
  def register_activation(%{dopamine: d, serotonin: s}) when is_number(d) and is_number(s) do
    GenServer.cast(__MODULE__, {:register_activation, d, s})
  end

  @doc "Ticks the mood state forward, applying decay."
  def tick, do: GenServer.cast(__MODULE__, :tick)

  ## GenServer Callbacks

  def init(_) do
    state = %{
      intensities: Map.new(@moods, fn m -> {m, 0.0} end),
      last_updated: now()
    }

    {:ok, state}
  end

  def handle_call(:current_mood, _from, %{intensities: intensities} = state) do
    mood = Enum.max_by(intensities, fn {_mood, intensity} -> intensity end) |> elem(0)
    {:reply, mood, state}
  end

  def handle_call({:mood_score, mood}, _from, %{intensities: intensities} = state) do
    {:reply, Map.get(intensities, mood, 0.0), state}
  end

  def handle_cast({:register_activation, dopamine, serotonin}, state) do
    mood = mood_from_neurotransmitters(dopamine, serotonin)
    new_state = reinforce_mood(mood, dopamine, state)
    {:noreply, new_state}
  end

  def handle_cast(:tick, state) do
    {:noreply, decay(state)}
  end

  ## Helpers

  defp now(), do: System.system_time(:millisecond)

  defp decay(%{intensities: intensities, last_updated: last} = state) do
    elapsed_ms = now() - last
    decay_factor = @decay_rate * (elapsed_ms / 1000)

    updated =
      Enum.map(intensities, fn {mood, intensity} ->
        new_intensity = max(intensity - decay_factor, 0.0)
        {mood, Float.round(new_intensity, 4)}
      end)
      |> Enum.into(%{})

    %{state | intensities: updated, last_updated: now()}
  end

  defp reinforce_mood(mood, strength, %{intensities: intensities} = state) do
    updated = Map.update(intensities, mood, strength, &min(&1 + strength, 1.0))
    %{state | intensities: updated, last_updated: now()}
  end

  defp mood_from_neurotransmitters(dopamine, serotonin) do
    cond do
      dopamine > 0.6 and serotonin > 0.6 -> :happy
      dopamine > 0.6 and serotonin < 0.3 -> :excited
      dopamine < 0.3 and serotonin > 0.6 -> :reflective
      dopamine < 0.3 and serotonin < 0.3 -> :sad
      serotonin > 0.5 and dopamine < 0.5 -> :nostalgic
      true -> :neutral
    end
  end
end

