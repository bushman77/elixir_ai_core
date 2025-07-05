defmodule BrainCell do
  use GenServer
  require Logger
  alias __MODULE__
  alias Brain
  alias ElixirAiCore.Core

  @default_suppression_threshold 0.4
  @default_overstim_threshold 1.6

  @type id :: String.t()
  @type position :: {float(), float(), float()}
  @type connection :: %{target_id: id(), weight: float(), delay_ms: non_neg_integer()}
  @type substance :: :serotonin | :dopamine | :acetylcholine | :norepinephrine | atom()

  @type t :: %__MODULE__{
          id: id(),
          word: String.t(),
          type: atom(),
          pos: atom(),
          definition: String.t(),
          example: String.t() | nil,
          synonyms: [String.t()],
          antonyms: [String.t()],
          connections: [connection()],
          status: :active | :inactive | :suppressed | :overstimulated,
          activation: float(),
          position: position(),
          serotonin: float(),
          dopamine: float(),
          last_dose_at: integer() | nil,
          last_substance: substance() | nil
        }

  defstruct [
    :id,
    :word,
    :type,
    :pos,
    :definition,
    :example,
    :synonyms,
    :antonyms,
    :activation,
    :serotonin,
    :dopamine,
    :connections,
    :position,
    :status,
    :last_dose_at,
    :last_substance
  ]

  # Public API
  def start_link(%{id: id} = args) do
    GenServer.start_link(__MODULE__, args, name: via(id))
  end

  def via(id), do: {:via, Registry, {BrainCell.Registry, id}}

  def fire(id, strength) do
    GenServer.cast(via(id), {:fire, strength})
  end

  def state(id), do: GenServer.call(via(id), :get_state)

  # Server Callbacks
  def init(%{id: id}), do: init(id)

  def init(id) do
    state =
      Brain.get(Brain, id) ||
        %BrainCell{
          id: id,
          position: {0.0, 0.0, 0.0},
          activation: 0.0,
          connections: []
        }

    {:ok, state}
  end

  def handle_cast({:update_connections, new_connections}, state) do
    updated = %{state | connections: new_connections}
    Brain.put(Brain, updated)
    {:noreply, updated}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_cast({:fire, strength}, state) do
    Logger.debug("Firing cell #{state.id} with strength #{Float.round(strength, 3)}")

    Brain.put(Brain, state)

    Enum.each(state.connections || [], fn conn ->
      new_strength = strength * conn.weight

      Logger.debug(
        " → Sending to #{conn.target_id} (delay #{conn.delay_ms}ms, weight #{Float.round(conn.weight, 3)})"
      )

      BrainCell.fire(conn.target_id, new_strength)
    end)

    {:noreply, %{state | activation: state.activation + strength}}
  end

  @doc "Applies serotonin/dopamine changes, optionally tracking substance and time"
  def apply_chemical_change(
        %__MODULE__{} = cell,
        %{dopamine: d, serotonin: s},
        substance \\ nil,
        time \\ nil
      )
      when is_float(d) and is_float(s) do
    new_ser = Core.clamp(cell.serotonin + s, 0.0, 2.0)
    new_dop = Core.clamp(cell.dopamine + d, 0.0, 2.0)

    %__MODULE__{
      cell
      | serotonin: new_ser,
        dopamine: new_dop,
        last_substance: substance,
        last_dose_at: time,
        status: evaluate_status(new_ser, new_dop)
    }
  end

  @doc "Evaluates cell status from neurotransmitter levels and thresholds"
  def evaluate_status(serotonin, dopamine, suppression_threshold, overstim_threshold) do
    cond do
      serotonin <= suppression_threshold -> :suppressed
      dopamine > overstim_threshold -> :overstimulated
      true -> :active
    end
  end

  @doc "Evaluates cell status using default thresholds"
  def evaluate_status(serotonin, dopamine) do
    evaluate_status(
      serotonin,
      dopamine,
      @default_suppression_threshold,
      @default_overstim_threshold
    )
  end
end
