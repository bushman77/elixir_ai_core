defmodule Model.Intent do
  import Axon

  def build_model(vocab_size, embedding_dim, num_classes) do
    input_shape = {nil, 16} # sequence length 16
    input = input(input_shape, :f32)

    input
    |> embedding(vocab_size, embedding_dim)
    |> flatten()
    |> dense(64, activation: :relu)
    |> dropout(rate: 0.2)
    |> dense(num_classes, activation: :softmax)
  end
end

