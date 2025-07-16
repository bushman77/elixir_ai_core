defmodule ElixirAiCore.Repo.Migrations.CreateBrainCells do
  use Ecto.Migration

  def change do
    create table(:brain_cells, primary_key: false) do
      add :id, :string, primary_key: true

      add :word, :string, null: false
      add :pos, :string, null: false
      add :definition, :text
      add :example, :text

      add :examples, {:array, :string}, default: [], null: false
      add :synonyms, {:array, :string}, default: [], null: false
      add :antonyms, {:array, :string}, default: [], null: false
      add :connections, {:array, :string}, default: [], null: false
      add :position, {:array, :float}, default: fragment("ARRAY[0.0, 0.0, 0.0]::float8[]"), null: false

      add :type, :string
      add :function, :string

      add :activation, :float, default: 0.0, null: false
      add :serotonin, :float, default: 0.0, null: false
      add :dopamine, :float, default: 0.0, null: false

      add :status, :string, default: "active", null: false
      add :mood, :string, default: "neutral", null: false

      add :last_dose_at, :utc_datetime_usec
      add :last_substance, :string
add :semantic_atoms, {:array, :string}, default: []

      timestamps()
    end
  end
end

