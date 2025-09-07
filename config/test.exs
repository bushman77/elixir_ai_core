import Config

config :elixir_ai_core, Core.DB,
  username: "postgres",
  password: "postgres",
  database: "brain_test",
  hostname: "127.0.0.1",
  pool_size: 5,
  show_sensitive_data_on_connection_error: true

