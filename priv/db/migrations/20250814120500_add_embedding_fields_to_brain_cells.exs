defmodule ElixirAiCore.Repo.Migrations.AddEmbeddingFieldsToBrainCells do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS vector")

    alter table(:brain_cells) do
      add :embedding, :vector, size: 256
      add :embedding_model, :string
      add :embedding_updated_at, :utc_datetime_usec
    end

    execute("""
    CREATE INDEX IF NOT EXISTS brain_cells_embedding_ivfflat
    ON brain_cells USING ivfflat (embedding vector_l2_ops) WITH (lists = 100)
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS brain_cells_embedding_ivfflat")

    alter table(:brain_cells) do
      remove :embedding
      remove :embedding_model
      remove :embedding_updated_at
    end
    # (Keep the extension around; other objects may rely on it)
  end
end

