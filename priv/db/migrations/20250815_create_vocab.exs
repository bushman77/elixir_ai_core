defmodule ElixirAiCore.DB.Migrations.CreateVocab do
  use Ecto.Migration

  def change do
    create table(:vocab) do
      add :word, :text, null: false
      timestamps()
    end

    create unique_index(:vocab, [:word])
  end
end

