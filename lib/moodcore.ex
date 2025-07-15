defmodule MoodCore do
  @moduledoc """
  Tracks the AI's emotional state.

  Each mood has an intensity score that decays over time and is reinforced by BrainCell activity.
  """

  use GenServer

  @default_mood :neutral
  @decay_rate 0.01
  @decay_interval 5_000

  @mood_states [
    :neutral,
    :happy,
    :sad,
    :curious,
    :reflective,
    :nostalgic,
    :excited,
    :anxious
  ]

  # --- Public API ---

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Returns the current dominant mood."
  def current_mood(), do: GenServer.call(__MODULE__, :get_mood)

  @doc "Reinforces a mood with an optional strength (default: 1.0)."
  def reinforce(mood, strength \\ 1.0), do: GenServer.cast(__MODULE__, {:reinforce, mood, strength})

  @doc "Triggers a manual decay tick (usually unnecessary)."
  def decay(), do: GenServer.cast(__MODULE__, :decay)

  # --- Internal GenServer State: %{
  #   mood: atom(),
  #   intensities: %{mood => float},
  #   last_updated: DateTime.t()
  # }

  # --- GenServer Callbacks ---

  def init(_) do
    initial_state = %{
      mood: @default_mood,
      intensities: Map.new(@mood_states, &{&1, 0.0}),
      last_updated: now()
    }

    schedule_decay()
    {:ok, initial_state}
  end

  def handle_call(:get_mood, _from, state) do
    dominant = dominant_mood(state.intensities)
    {:reply, dominant, %{state | mood: dominant}}
  end

  def handle_cast({:reinforce, mood, strength}, %{intensities: intensities} = state) do
    updated = Map.update(intensities, mood, strength, &min(&1 + strength, 1.0))
    {:noreply, %{state | intensities: updated, last_updated: now()}}
  end

  def handle_cast(:decay, state), do: handle_decay(state)

  def handle_info(:decay, state), do: handle_decay(state)

  # --- Private ---

  defp handle_decay(%{intensities: intensities} = state) do
    decayed =
      Enum.map(intensities, fn {mood, value} ->
        {mood, max(0.0, value - @decay_rate)}
      end)

    schedule_decay()
    {:noreply, %{state | intensities: Map.new(decayed), last_updated: now()}}
  end

  defp dominant_mood(intensities) do
    Enum.max_by(intensities, fn {_mood, score} -> score end)
    |> elem(0)
  end

  defp schedule_decay, do: Process.send_after(self(), :decay, @decay_interval)

  defp now, do: DateTime.utc_now()
end

