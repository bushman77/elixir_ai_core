defmodule MoodCore do
  @moduledoc """
  Tracks an evolving emotional state influenced by neurotransmitters and nudges.

  Moods: :happy, :excited, :sad, :nostalgic, :reflective, :neutral, :grumpy
  Each mood has intensity in [0.0, 1.0], decaying over time unless reinforced.
  """

  use GenServer

  @moods [:happy, :excited, :sad, :nostalgic, :reflective, :neutral, :grumpy]
  @decay_rate_per_sec 0.005
  @tick_ms 1_000            # periodic decay tick
  @cooldown_step_ms 5_000   # step interval during cooldown ramp-down

  @type mood ::
          :happy | :excited | :sad | :nostalgic | :reflective | :neutral | :grumpy

  @type state :: %{
          intensities: %{mood => float()},
          last_updated: integer()
        }

  ## ── Public API ────────────────────────────────────────────────────────────

  def start_link(_opts),
    do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Returns the current dominant mood."
  @spec current_mood() :: mood
  def current_mood, do: GenServer.call(__MODULE__, :current_mood)

  @doc "Attach the current mood to a SemanticInput-like map in a pipe-friendly way."
  @spec attach_mood(map()) :: map()
  def attach_mood(%{} = input) do
    mood =
      case Process.whereis(__MODULE__) do
        nil -> :neutral
        _pid -> current_mood()
      end

    Map.put(input, :mood, mood)
  end

  # Belt-and-suspenders: if something upstream returned :ok, just pass it through
  def attach_mood(other), do: other

  @doc "Returns the current score (0.0 to 1.0) of the given mood."
  @spec mood_score(mood) :: float()
  def mood_score(m), do: GenServer.call(__MODULE__, {:mood_score, m})

  @doc "Registers neurotransmitter levels from a firing BrainCell."
  @spec register_activation(%{dopamine: number(), serotonin: number()}) :: :ok
  def register_activation(%{dopamine: d, serotonin: s})
      when is_number(d) and is_number(s) do
    GenServer.cast(__MODULE__, {:register_activation, d, s})
  end

  @doc """
  Apply a transient mood nudge with optional TTL-based cooldown.
  Example: `nudge(:negative, amount: 0.4, ttl: 90_000)`
  """
  @spec nudge(:positive | :negative, keyword()) :: :ok
  def nudge(polarity, opts \\ []) when polarity in [:positive, :negative] do
    amount = opts[:amount] || 0.2
    ttl    = opts[:ttl] || 0
    GenServer.cast(__MODULE__, {:nudge, polarity, amount, ttl})
  end

  # Back-compat if you already called MoodCore.apply/2 elsewhere
  @doc false
  def apply(polarity, opts \\ []), do: nudge(polarity, opts)

  @doc "Advance mood state by applying decay (also runs on a periodic timer)."
  @spec tick() :: :ok
  def tick, do: GenServer.cast(__MODULE__, :tick)

  ## ── GenServer ─────────────────────────────────────────────────────────────

  @impl true
  def init(_) do
    state = %{
      intensities: Map.new(@moods, &{&1, 0.0}),
      last_updated: now_ms()
    }

    # Periodic decay
    :timer.send_interval(@tick_ms, :tick)
    {:ok, state}
  end

  @impl true
  def handle_call(:current_mood, _from, %{intensities: intensities} = state) do
    {dom, _} = Enum.max_by(intensities, fn {_m, score} -> score end, fn -> {:neutral, 0.0} end)
    {:reply, dom, state}
  end

  @impl true
  def handle_call({:mood_score, mood}, _from, %{intensities: intensities} = state) do
    {:reply, Map.get(intensities, mood, 0.0), state}
  end

  @impl true
  def handle_cast({:register_activation, d, s}, state) do
    mood = mood_from_neurotransmitters(d, s)
    {:noreply, reinforce_mood(mood, clamp01(max(d, s)), state)}
  end

  @impl true
  def handle_cast({:nudge, :negative, amount, ttl}, state) do
    s = reinforce_mood(:grumpy, amount, state)
    if ttl > 0, do: Process.send_after(self(), {:cooldown, :grumpy}, ttl)
    {:noreply, s}
  end

  @impl true
  def handle_cast({:nudge, :positive, amount, ttl}, state) do
    s = reinforce_mood(:happy, amount, state)
    if ttl > 0, do: Process.send_after(self(), {:cooldown, :happy}, ttl)
    {:noreply, s}
  end

  @impl true
  def handle_cast(:tick, state), do: {:noreply, decay(state)}

  # Cooldown gradually reduces a target mood toward 0 in steps
  @impl true
  def handle_info({:cooldown, mood}, %{intensities: ints} = state) do
    current = Map.get(ints, mood, 0.0)
    step = 0.1
    new_val = clamp01(current - step)
    new_ints = Map.put(ints, mood, Float.round(new_val, 4))

    if new_val > 0.0 do
      Process.send_after(self(), {:cooldown, mood}, @cooldown_step_ms)
    end

    {:noreply, %{state | intensities: new_ints, last_updated: now_ms()}}
  end

  @impl true
  def handle_info(:tick, state), do: {:noreply, decay(state)}

  @impl true
def handle_info(_msg, state), do: {:noreply, state}

  ## ── Internals ─────────────────────────────────────────────────────────────

  defp now_ms, do: System.system_time(:millisecond)

  defp decay(%{intensities: intensities, last_updated: last} = state) do
    elapsed_secs = (now_ms() - last) / 1000
    decay_factor = @decay_rate_per_sec * elapsed_secs

    new_intensities =
      for {mood, intensity} <- intensities, into: %{} do
        {mood, Float.round(max(intensity - decay_factor, 0.0), 4)}
      end

    %{state | intensities: new_intensities, last_updated: now_ms()}
  end

  defp reinforce_mood(mood, strength, %{intensities: intensities} = state) do
    new_intensity =
      Map.get(intensities, mood, 0.0)
      |> Kernel.+(strength)
      |> clamp01()
      |> Float.round(4)

    %{state | intensities: Map.put(intensities, mood, new_intensity), last_updated: now_ms()}
  end

  defp clamp01(x) when is_number(x) do
    cond do
      x < 0.0 -> 0.0
      x > 1.0 -> 1.0
      true -> x
    end
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

