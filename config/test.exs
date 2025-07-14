import Config

config :elixir_ai_core, Core.DB,
  username: "postgres",
  password: "postgres",
  database: "brain_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :elixir_ai_core, ecto_repos: [Core.DB]

