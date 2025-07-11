defmodule ElixirAiCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_ai_core,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_options: [warnings_as_errors: false],
      elixirc_paths: ["lib", "test"],
      config_path: "config/config.exs",
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {ElixirAiCore.Application, []}
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.5.1"},
      {:axon, "~> 0.5.1"},
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
      seed: ["run priv/seed.exs"]
    ]
  end
end
