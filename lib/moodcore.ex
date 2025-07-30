defmodule MoodCore do
  use GenServer

  @moduledoc """
  MoodCore tracks the evolving emotional state of the system, influenced by
  dopamine and serotonin levels from active BrainCells.

  ## Mood Logic
  - Moods include: :happy, :excited, :sad, :nostalgic, :reflective, :neutral
  - Each mood has a dynamic intensity between 0.0 and 1.0
  - Intensity decays over time unless reinforced by BrainCell activation
  """

  @moods [:happy, :excited, :sad, :nostalgic, :reflective, :neutral]
  @decay_rate_per_sec 0.005

  @type mood :: :happy | :excited | :sad | :nostalgic | :reflective | :neutral
  @type state :: %{
          intensities: %{mood => float},
          last_updated: integer
        }

  ## Public API

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Returns the current dominant mood."
  @spec current_mood() :: mood
  def current_mood, do: GenServer.call(__MODULE__, :current_mood)

  @doc "Returns the current score (0.0 to 1.0) of the given mood."
  @spec mood_score(mood) :: float
  def mood_score(mood), do: GenServer.call(__MODULE__, {:mood_score, mood})

  @doc "Registers neurotransmitter levels from a firing BrainCell."
  @spec register_activation(%{dopamine: float, serotonin: float}) :: :ok
  def register_activation(%{dopamine: d, serotonin: s}) when is_number(d) and is_number(s) do
    GenServer.cast(__MODULE__, {:register_activation, d, s})
  end

  @doc "Advances mood state forward by applying decay."
  def tick, do: GenServer.cast(__MODULE__, :tick)

  ## GenServer Callbacks

  @impl true
  def init(_) do
    state = %{
      intensities: Map.new(@moods, &{&1, 0.0}),
      last_updated: now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:current_mood, _from, %{intensities: intensities} = state) do
    dominant = Enum.max_by(intensities, fn {_m, score} -> score end) |> elem(0)
    {:reply, dominant, state}
  end

  @impl true
  def handle_call({:mood_score, mood}, _from, %{intensities: intensities} = state) do
    {:reply, Map.get(intensities, mood, 0.0), state}
  end

  @impl true
  def handle_cast({:register_activation, dopamine, serotonin}, state) do
    mood = mood_from_neurotransmitters(dopamine, serotonin)
    updated_state = reinforce_mood(mood, dopamine, state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast(:tick, state), do: {:noreply, decay(state)}

  ## Internals

  defp now, do: System.system_time(:millisecond)

  defp decay(%{intensities: intensities, last_updated: last} = state) do
    elapsed_secs = (now() - last) / 1000
    decay_factor = @decay_rate_per_sec * elapsed_secs

    new_intensities =
      Enum.into(intensities, %{}, fn {mood, intensity} ->
        {mood, Float.round(max(intensity - decay_factor, 0.0), 4)}
      end)

    %{state | intensities: new_intensities, last_updated: now()}
  end

  defp reinforce_mood(mood, strength, %{intensities: intensities} = state) do
    new_intensity = min(Map.get(intensities, mood, 0.0) + strength, 1.0)
    updated = Map.put(intensities, mood, Float.round(new_intensity, 4))
    %{state | intensities: updated, last_updated: now()}
  end

  defp mood_from_neurotransmitters(d, s) do
    cond do
      d > 0.6 and s > 0.6 -> :happy
      d > 0.6 and s < 0.3 -> :excited
      d < 0.3 and s > 0.6 -> :reflective
      d < 0.3 and s < 0.3 -> :sad
      s > 0.5 and d < 0.5 -> :nostalgic
      true -> :neutral
    end
  end
end

