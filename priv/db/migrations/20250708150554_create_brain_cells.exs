defmodule ElixirAiCore.Repo.Migrations.CreateBrainCells do
  use Ecto.Migration

  def change do
    create table(:brain_cells, primary_key: false) do
      add :id, :string, primary_key: true

      add :word, :string
      add :pos, :string
      add :definition, :text
      add :example, :text
add :examples, {:array, :string}, default: []
add :position, {:array, :float}, default: [0.0, 0.0, 0.0]
      add :synonyms, {:array, :string}, default: []
      add :antonyms, {:array, :string}, default: []

      add :type, :string
      add :function, :string
      add :activation, :float, default: 0.0
      add :serotonin, :float, default: 0.0
      add :dopamine, :float, default: 0.0

      add :connections, {:array, :string}, default: []
      
      add :status, :string
      add :last_dose_at, :utc_datetime_usec
      add :last_substance, :string

      timestamps()
    end
  end
end

