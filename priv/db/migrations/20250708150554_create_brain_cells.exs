defmodule ElixirAiCore.Repo.Migrations.CreateBrainCells do
  use Ecto.Migration

  def change do
    create table(:brain_cells, primary_key: false) do
      add :id, :string, primary_key: true
      add :token_ids, {:array, :integer}, default: []
      add :word, :string
      add :pos, :string
      add :definition, :string
      add :example, :string
      add :synonyms, {:array, :string}
      add :antonyms, {:array, :string}
      add :function, :string
      add :type, :string
      add :status, :string, default: "inactive"
      add :activation, :float, default: 0.0
      add :dopamine, :float, default: 0.0
      add :serotonin, :float, default: 0.0
      add :connections, {:array, :string}, default: []
      add :position, {:array, :float}
      add :semantic_atoms, {:array, :string}, default: []
      add :last_dose_at, :utc_datetime_usec
      add :last_substance, :string

      timestamps()
    end

    create index(:brain_cells, [:word])
    # You may remove or replace this line based on your indexing strategy:
    # create index(:brain_cells, [:token_ids])  # optional — supported by Postgres 9.4+ with GIN/GIN indexing
  end
end

