defmodule Core.DB do
  use Ecto.Repo,
    otp_app: :elixir_ai_core,
    adapter: Ecto.Adapters.Postgres

def cell_exists?(id) do
  import Ecto.Query
  from(b in BrainCell, where: b.id == ^id, select: 1)
  |> ElixirAiCore.Repo.exists?()
end

end

