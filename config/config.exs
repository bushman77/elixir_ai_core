# config/config.exs
import Config

config :logger, level: :info
config :tesla, disable_deprecated_builder_warning: true

config :elixir_ai_core, ecto_repos: [Core.DB]

config :elixir_ai_core, Core.DB,
  username: "postgres",
  password: "postgres",
  database: "brain",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

