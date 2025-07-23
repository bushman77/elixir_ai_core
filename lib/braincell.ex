defmodule BrainCell do
  use GenServer
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  @table "brain_cells"
@primary_key {:id, :string, autogenerate: false}
schema "brain_cells" do
  field :word, :string
  field :pos, :string
  field :definition, :string
  field :example, :string
  field :synonyms, {:array, :string}
  field :antonyms, {:array, :string}
  field :function, :string

  # Updated to Ecto.Enum for atom support
  field :type, Ecto.Enum, values: [:noun, :verb, :concept, :phrase, :emotion, :synapse]
  field :status, Ecto.Enum, values: [:inactive, :active, :dormant, :decayed], default: :inactive

  # ML + neuro-symbolic fields
  field :activation, :float, default: 0.0
  field :dopamine, :float, default: 0.0
  field :serotonin, :float, default: 0.0
  field :connections, {:array, :string}, default: []
  field :position, {:array, :float}

  # New field for semantic propagation
  field :semantic_atoms, {:array, :string}, default: []

  # Optional neurotransmitter info
  field :last_dose_at, :utc_datetime_usec
  field :last_substance, :string

  timestamps()
end

  # ====================
  # GenServer API
  # ====================

  def start_link(%BrainCell{id: id} = cell) do
    GenServer.start_link(__MODULE__, cell, name: via(id))
  end

  defp via(id), do: {:via, Registry, {Core.Registry, id}}

  def init(%BrainCell{} = cell) do
    {:ok, sanitize(cell)}
  end

  defp sanitize(cell) do
    modulated = modulate(cell.activation, cell.dopamine, cell.serotonin)
    %{cell | modulated_activation: modulated, connections: cell.connections || %{}}
  end

  defp modulate(activation, dopamine, serotonin) do
    Float.round(activation + dopamine - serotonin, 4)
  end

  # Public interface

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def fire(pid, amount \\ 0.1) do
    GenServer.cast(pid, {:fire, amount})
  end

  def apply_substance(pid, :dopamine, amount) do
    GenServer.cast(pid, {:apply_dopamine, amount})
  end

  def apply_substance(pid, :serotonin, amount) do
    GenServer.cast(pid, {:apply_serotonin, amount})
  end

  # GenServer callbacks

  def handle_call(:get_state, _from, %BrainCell{} = cell) do
    {:reply, cell, cell}
  end

  def handle_cast({:fire, amount}, %BrainCell{} = cell) do
    updated = %{
      cell
      | activation: cell.activation + amount,
        modulated_activation: modulate(cell.activation + amount, cell.dopamine, cell.serotonin)
    }

    {:noreply, updated}
  end

  def handle_cast({:apply_dopamine, amount}, %BrainCell{} = cell) do
    now = DateTime.utc_now()
    updated = %{
      cell
      | dopamine: cell.dopamine + amount,
        modulated_activation: modulate(cell.activation, cell.dopamine + amount, cell.serotonin),
        last_dose_at: now,
        last_substance: "dopamine"
    }

    {:noreply, updated}
  end

  def handle_cast({:apply_serotonin, amount}, %BrainCell{} = cell) do
    now = DateTime.utc_now()
    updated = %{
      cell
      | serotonin: cell.serotonin + amount,
        modulated_activation: modulate(cell.activation, cell.dopamine, cell.serotonin + amount),
        last_dose_at: now,
        last_substance: "serotonin"
    }

    {:noreply, updated}
  end
end

