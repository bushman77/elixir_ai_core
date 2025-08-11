defmodule ElixirAiCore.Repo.Migrations.CreateBrainCells do
  use Ecto.Migration

  def change do
    create table(:brain_cells, primary_key: false) do
      # use :text to future-proof IDs like "would|modal|1" and longer phrases
      add :id, :text, primary_key: true

      add :token_ids, {:array, :integer}, default: []

      # long text fields → :text
      add :word, :text
      add :pos, :text
      add :definition, :text
      add :synonyms, {:array, :text}, default: []
      add :antonyms, {:array, :text}, default: []
      add :example, :text
      add :function, :text

      # enums are stored as strings; varchar vs text doesn't matter here, but keep as :string
      add :type, :string

      # status has a default; keep as :string (Ecto.Enum will cast)
      add :status, :string, default: "inactive"

      # activations/neurochem
      add :activation, :float, default: 0.0
      add :modulated_activation, :float, default: 0.0
      add :dopamine, :float, default: 0.0
      add :serotonin, :float, default: 0.0

      # arrays of potentially long strings → {:array, :text}
      add :connections, {:array, :text}, default: []
      add :position, {:array, :float}
      add :semantic_atoms, {:array, :text}, default: []

      add :last_dose_at, :utc_datetime_usec
      add :last_substance, :string

      timestamps()
    end

    create index(:brain_cells, [:word])
    create index(:brain_cells, [:token_ids], using: :gin)

    # Optional: DB-level guard for allowed statuses (matches your Ecto.Enum)
    execute """
    ALTER TABLE brain_cells
    ADD CONSTRAINT status_must_be_valid
      CHECK (status IN ('inactive','active','dormant','decayed'));
    """
  end
end

