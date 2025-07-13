defmodule BrainCell do
  use GenServer
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  @default_suppression_threshold 0.4
  @default_overstim_threshold 1.6

  @primary_key {:id, :string, autogenerate: false}
  schema "brain_cells" do
    field :word, :string
    field :pos, :string
    field :definition, :string
    field :example, :string
    field :examples, {:array, :string}, default: []
    field :synonyms, {:array, :string}, default: []
    field :antonyms, {:array, :string}, default: []
    field :type, :string
    field :function, :string
    field :activation, :float, default: 0.0
    field :serotonin, :float, default: 0.0
    field :dopamine, :float, default: 0.0
    field :connections, {:array, :string}, default: []
    field :position, {:array, :float}, default: [0.0, 0.0, 0.0]
    field :status, Ecto.Enum, values: [:active, :suppressed, :overstimulated]

    field :last_dose_at, :utc_datetime_usec
    field :last_substance, :string
    timestamps()
  end

  # -- Changeset for DB
  def changeset(cell, attrs) do
    cell
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:id, :word, :pos])
  end

  # -- GenServer API

  def start_link(%{id: id} = args) do
    GenServer.start_link(__MODULE__, args, name: via(id))
  end

  def via(id), do: {:via, Registry, {BrainCell.Registry, id}}

  def fire(id, strength), do: GenServer.cast(via(id), {:fire, strength})

  def state(id), do: GenServer.call(via(id), :get_state)

  # -- GenServer Callbacks

  def init(%{id: id} = args) do
    state = struct(__MODULE__, Map.merge(%{
      position: "0.0,0.0,0.0",
      activation: 0.0,
      connections: [],
      status: "active"
    }, args))

    {:ok, state}
  end

  def handle_cast({:update_connections, new_connections}, state) do
    updated = %{state | connections: new_connections}
    Brain.put(updated)
    {:noreply, updated}
  end

  def handle_cast({:fire, strength}, state) do
    Brain.put(state)

    Enum.each(state.connections || [], fn target_id ->
      BrainCell.fire(target_id, strength * 1.0)
    end)

    {:noreply, %{state | activation: state.activation + strength}}
  end

  def handle_info({:register_self, registry, id, _cell}, state) do
    Registry.register(registry, id, state)
    {:noreply, state}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call(:status, _from, state), do: {:reply, {:ok, state}, state}

  # -- Chemical simulation
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

  def evaluate_status(serotonin, dopamine, suppression_threshold, overstim_threshold) do
    cond do
      serotonin <= suppression_threshold -> "suppressed"
      dopamine > overstim_threshold -> "overstimulated"
      true -> "active"
    end
  end

  def evaluate_status(serotonin, dopamine) do
    evaluate_status(
      serotonin,
      dopamine,
      @default_suppression_threshold,
      @default_overstim_threshold
    )
  end
end

