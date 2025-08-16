# lib/core/vocab.ex
defmodule Core.Vocab do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.DB

  @primary_key {:id, :id, autogenerate: true}
  schema "vocab" do
    field :word, :string
    timestamps()
  end

  def changeset(v, attrs), do:
    v |> cast(attrs, [:word]) |> validate_required([:word]) |> unique_constraint(:word)

  def get(word) when is_binary(word),
    do: DB.get_by(__MODULE__, word: String.downcase(word))

  def upsert!(word) when is_binary(word) do
    word = String.downcase(word)
    %__MODULE__{}
    |> changeset(%{word: word})
    |> DB.insert!(on_conflict: [set: [word: word]], conflict_target: :word)
  rescue
    _ -> get(word) # if conflict returns error on your DB, fallback to get
  end
end

