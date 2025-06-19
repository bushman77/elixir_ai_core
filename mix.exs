defmodule ElixirAiCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_ai_core,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ElixirAiCore.Application, []}
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.5"},
      {:axon, "~> 0.5"}
    ]
  end
end