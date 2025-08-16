defmodule ElixirAiCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_ai_core,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_options: [warnings_as_errors: false],
      elixirc_paths: elixirc_paths(Mix.env()),
      config_path: "config/config.exs",
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

defp elixirc_paths(:test), do: ["lib", "test"]
defp elixirc_paths(_),     do: ["lib"]


  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {ElixirAiCore.Application, []}
    ]
  end

defp deps do
  [
{:pgvector, "~> 0.3"},
 {:axon, "~> 0.7.0"},
  {:nx, "~> 0.9.1"},
    {:jason, "~> 1.4"},
    {:tesla, "~> 1.4"},
    {:hackney, "~> 1.18"},
    {:mox, "~> 1.1", only: :test},
    {:ecto, "~> 3.10"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, ">= 0.0.0"}
  ]
end

  defp aliases do
    [
setup: ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
  test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
