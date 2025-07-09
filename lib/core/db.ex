defmodule Core.DB do
  use Ecto.Repo,
    otp_app: :elixir_ai_core,
    adapter: Ecto.Adapters.Postgres
end

