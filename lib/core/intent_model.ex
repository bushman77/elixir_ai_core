defmodule Core.IntentModel do
  import Nx.Defn
  alias Axon

  def build_model(input_shape) do
    Axon.input("input", shape: input_shape)
    |> Axon.dense(8, activation: :relu)
    |> Axon.dense(4, activation: :softmax)
  end
end

