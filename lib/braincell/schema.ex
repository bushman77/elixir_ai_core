defmodule BCell do
import Ecto.Changeset

  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  @derive {Inspect, only: [:id, :word, :pos, :definition]}

  schema "brain_cells" do
    # <-- Secondary index
    field(:word, :string)

    field(:pos, Ecto.Enum,
      values: [
        :noun,
        :verb,
        :adjective,
        :adverb,
        :interjection,
        :conjunction,
        :preposition,
        :unknown
      ]
    )


def changeset(cell, attrs) do
  cell
  |> cast(attrs, [:word, :pos, :definition, :example, :synonyms, :antonyms, :type, :activation, :serotonin, :dopamine, :connections, :position, :status, :last_dose_at, :last_substance])
  |> validate_required([:word, :pos, :definition])
  |> put_change(:inserted_at, DateTime.utc_now())   # This is optional but explicit
  |> put_change(:updated_at, DateTime.utc_now())   # Usually automatic, but explicit works
end


    field(:definition, :string)
    field(:example, :string)
    field(:synonyms, {:array, :string})
    field(:antonyms, {:array, :string})
    field(:type, :string)
    field(:activation, :float)
    field(:serotonin, :float)
    field(:dopamine, :float)
    field(:connections, {:array, :string})
    # You can use %{x: 0.0, y: 0.0, z: 0.0}
    field(:position, {:array, :float})
    field(:status, Ecto.Enum, values: [:active, :inactive])
    field(:last_dose_at, :utc_datetime_usec)
    field(:last_substance, :string)
    timestamps()
  end
end
