defmodule BrainCell do
  use GenServer
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

@primary_key {:id, :string, autogenerate: false}
  @table "brain_cells"

  schema @table do
    # Indexable / long text
    field :word, :string
    field :pos, :string
    field :definition, :string
    field :example, :string
    field :function, :string

    # Arrays
    field :synonyms, {:array, :string}, default: []
    field :antonyms, {:array, :string}, default: []
    field :semantic_atoms, {:array, :string}, default: []
    field :connections, {:array, :string}, default: []

    # IDs / embeddings
    field :token_ids, {:array, :integer}, default: []

    # Classification
    field :type, Ecto.Enum, values: [:noun, :verb, :concept, :phrase, :emotion, :synapse]
    field :status, Ecto.Enum, values: [:inactive, :active, :dormant, :decayed], default: :inactive

    # Neuro-symbolic fields
    field :activation, :float, default: 0.0
    field :modulated_activation, :float, default: 0.0
    field :dopamine, :float, default: 0.0
    field :serotonin, :float, default: 0.0

    # Spatial
    field :position, {:array, :float}, default: [0.0, 0.0, 0.0]

    # Chemical dosing info
    field :last_dose_at, :utc_datetime_usec
    field :last_substance, :string

    timestamps()
  end

  # Optional: tighten up inputs so APIs can't poison inserts
  def changeset(cell, attrs) do
    cell
    |> cast(attrs, [
      :id, :word, :pos, :definition, :example, :function, :type, :status,
      :synonyms, :antonyms, :semantic_atoms, :connections, :token_ids,
      :activation, :modulated_activation, :dopamine, :serotonin,
      :position, :last_dose_at, :last_substance
    ])
    |> validate_length(:definition, max: 20_000)
    |> validate_length(:example, max: 10_000)
  end
  # --------------------
  # GenServer API
  # --------------------

  def start_link(%BrainCell{id: id} = cell) do
    GenServer.start_link(__MODULE__, cell, name: via(id))
  end

  defp via(id), do: {:via, Registry, {Core.Registry, id}}

  def init(%BrainCell{id: id} = state) do
    send(Brain, {:cell_started, {id, self()}})
    {:ok, state}
  end

  # Public interface
# In BrainCell
def get(id) do
  case Registry.lookup(Core.Registry, id) do
    [{pid, _}] -> get_state(pid)
    _ -> nil
  end
end

  def get_state(pid), do: GenServer.call(pid, :get_state)

  def fire(pid, amount \\ 0.1), do: GenServer.cast(pid, {:fire, amount})

  def apply_substance(pid, :dopamine, amount), do: GenServer.cast(pid, {:apply_dopamine, amount})
  def apply_substance(pid, :serotonin, amount), do: GenServer.cast(pid, {:apply_serotonin, amount})

  # --------------------
  # GenServer Callbacks
  # --------------------

  def handle_call(:get_state, _from, %BrainCell{} = cell), do: {:reply, cell, cell}

  def handle_cast({:fire, amount}, %BrainCell{} = cell) do
    new_activation = clamp(cell.activation + amount)
    updated = %{
      cell
      | activation: new_activation,
        modulated_activation: modulated_activation(new_activation, cell.dopamine, cell.serotonin)
    }
    {:noreply, updated}
  end

  def handle_cast({:apply_dopamine, amount}, %BrainCell{} = cell) do
    now = DateTime.utc_now()
    new_dopamine = clamp(cell.dopamine + amount)

    updated = %{
      cell
      | dopamine: new_dopamine,
        modulated_activation: modulated_activation(cell.activation, new_dopamine, cell.serotonin),
        last_dose_at: now,
        last_substance: "dopamine"
    }
    {:noreply, updated}
  end

  def handle_cast({:apply_serotonin, amount}, %BrainCell{} = cell) do
    now = DateTime.utc_now()
    new_serotonin = clamp(cell.serotonin + amount)

    updated = %{
      cell
      | serotonin: new_serotonin,
        modulated_activation: modulated_activation(cell.activation, cell.dopamine, new_serotonin),
        last_dose_at: now,
        last_substance: "serotonin"
    }
    {:noreply, updated}
  end

  # --------------------
  # Helpers
  # --------------------

  def modulated_activation(activation, dopamine, serotonin) do
    Float.round(activation + dopamine - serotonin, 4)
  end

  defp clamp(value) when value < 0.0, do: 0.0
  defp clamp(value) when value > 1.0, do: 1.0
  defp clamp(value), do: value
end

