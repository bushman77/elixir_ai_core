defmodule ElixirAiCore.Repo.Migrations.CreateBrainCells do
  use Ecto.Migration

  def change do
    create table(:brain_cells, primary_key: false) do
      add :id, :text, primary_key: true
      add :word, :text, null: false
      add :pos,  :text, null: false
      add :definition, :text
      add :example, :text
      add :function, :text
      add :synonyms,       {:array, :text}, default: []
      add :antonyms,       {:array, :text}, default: []
      add :semantic_atoms, {:array, :text}, default: []
      add :type, :string
      add :status, :string, default: "inactive"

      # ⛔️ remove these from this file:
      # add :embedding, :vector, size: 256
      # add :embedding_model, :string
      # add :embedding_updated_at, :utc_datetime_usec

      add :activation, :float, default: 0.0
      add :modulated_activation, :float, default: 0.0
      add :dopamine, :float, default: 0.0
      add :serotonin, :float, default: 0.0
      add :position, {:array, :float}
      add :connections, {:array, :map}, default: fragment("'{}'::jsonb[]"), null: false
      add :last_dose_at,   :utc_datetime_usec
      add :last_substance, :string
      add :token_id, :bigint
      timestamps()
    end

    create index(:brain_cells, [:word])
    create index(:brain_cells, [:token_id])

    execute("""
    ALTER TABLE brain_cells
    ADD CONSTRAINT brain_cells_status_check
    CHECK (status IN ('inactive','active','dormant','decayed'));
    """)
  end
end

