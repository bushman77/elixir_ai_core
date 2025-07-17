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
    field :mood, Ecto.Enum,
      values: [:neutral, :happy, :sad, :curious, :reflective, :nostalgic, :excited, :anxious],
      default: :neutral
field :semantic_atoms, {:array, :string}, default: []

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

def start_if_needed(%{id: id} = cell) do
  case Registry.lookup(BrainCell.Registry, id) do
    [] ->
      BrainCell.start_link(cell)
    _ ->
      :ok
  end
end


  def fire(id, strength), do: GenServer.cast(via(id), {:fire, strength})

  def state(id), do: GenServer.call(via(id), :get_state)

  # -- GenServer Callbacks

  @impl true
  def init(%{id: _id} = args) do
    cleaned =
      args
      |> Map.merge(%{
        activation: 0.0,
        connections: [],
        position: [0.0, 0.0, 0.0],
        status: :active
      })
      |> sanitize()

    state = struct(__MODULE__, cleaned)
    {:ok, state}
  end

  @impl true
  def handle_cast({:update_connections, new_connections}, state) do
    updated = %{state | connections: new_connections}
    Brain.put(updated)
    {:noreply, updated}
  end

  @impl true
  def handle_cast({:fire, strength}, state) do
    Brain.put(state)

    Enum.each(state.connections || [], fn target_id ->
      BrainCell.fire(target_id, strength * 1.0)
    end)

    {:noreply, %{state | activation: state.activation + strength}}
  end

  @impl true
  def handle_info({:register_self, registry, id, _cell}, state) do
    Registry.register(registry, id, state)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call(:status, _from, state), do: {:reply, {:ok, state}, state}

  # -- Chemical simulation
  def apply_chemical_change(%__MODULE__{} = cell, %{dopamine: d, serotonin: s}, substance \\ nil, time \\ nil)
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

  def evaluate_status(serotonin, dopamine) do
    evaluate_status(
      serotonin,
      dopamine,
      @default_suppression_threshold,
      @default_overstim_threshold
    )
  end

  def evaluate_status(serotonin, dopamine, suppression_threshold, overstim_threshold) do
    cond do
      serotonin <= suppression_threshold -> :suppressed
      dopamine > overstim_threshold -> :overstimulated
      true -> :active
    end
  end

  # -- Sanitizers

  defp sanitize(attrs) do
    attrs
    |> Map.update(:connections, [], &ensure_list/1)
    |> Map.update(:examples, [], &ensure_list/1)
    |> Map.update(:synonyms, [], &ensure_list/1)
    |> Map.update(:antonyms, [], &ensure_list/1)
    |> Map.update(:position, [0.0, 0.0, 0.0], &ensure_floats/1)
    |> Map.update(:status, :active, &ensure_status/1)
  end

  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(other) do
    Logger.warn("[BrainCell] Expected list, got #{inspect(other)}. Coercing to [].")
    []
  end

  defp ensure_floats(list) when is_list(list), do: Enum.map(list, &to_float/1)
  defp ensure_floats(_), do: [0.0, 0.0, 0.0]

  defp to_float(x) when is_float(x), do: x
  defp to_float(x) when is_integer(x), do: x * 1.0
  defp to_float(x) when is_binary(x) do
    case Float.parse(x) do
      {f, _} -> f
      _ -> 0.0
    end
  end
  defp to_float(_), do: 0.0

  defp ensure_status(val) when is_atom(val), do: val
  defp ensure_status(val) when is_binary(val) do
    String.to_existing_atom(val)
  rescue
    _ -> :active
  end
  defp ensure_status(_), do: :active
end

