defmodule ElixirAiCore.Repo.Migrations.CreateBrainCells do
  use Ecto.Migration

  def change do
    create table(:brain_cells, primary_key: false) do
      add :id, :string, primary_key: true
      add :word, :string
      add :pos, :string
      add :definition, :text
      add :example, :text
      add :synonyms, {:array, :string}
      add :antonyms, {:array, :string}
      add :type, :string
      add :activation, :float
      add :serotonin, :float
      add :dopamine, :float
      add :connections, {:array, :string}
      add :position, {:array, :float}
      add :status, :string
      add :last_dose_at, :utc_datetime_usec
      add :last_substance, :string

      timestamps()
    end
  end
end

