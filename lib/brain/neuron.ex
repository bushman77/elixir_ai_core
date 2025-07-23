defmodule Brain.Neuron do
  @moduledoc """
  Tiny neural unit used to modulate BrainCell activation based on chemistry + current activation.
  """

  alias Axon
  alias Nx

  @input_size 3  # serotonin, dopamine, activation

  # Build once; reuse.
  def build_model do
    Axon.input("features", shape: {nil, @input_size})
    |> Axon.dense(8, activation: :relu)
    |> Axon.dense(1, activation: :sigmoid) # output in 0..1
  end

  # Create random params (bootstrapping, before training).
  def init_params do
    model = build_model()
    Axon.init(model, %{"features" => Nx.template({1, @input_size}, :f32)})
  end

  # Run a forward pass with provided params and feature triple.
  def predict(params, serotonin, dopamine, activation) do
    model = build_model()

    x =
      Nx.tensor([[serotonin, dopamine, activation]], type: :f32)

    Axon.predict(model, params, %{"features" => x})
    |> Nx.squeeze()
    |> Nx.to_number()
  end
end

