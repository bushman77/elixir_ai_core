#Mix.install([
#  {:axon, "~> 0.6.1"},
#  {:nx, "~> 0.6.4"},
#  {:exla, "~> 0.6.4", optional: true}
#])

Nx.global_default_backend(Nx.BinaryBackend)

alias Axon
require Nx

# Simulated dataset (replace with your real values)
x_data = [
  Nx.tensor([1, 2, 3, 4, 0, 0, 0, 0, 0, 0]),
  Nx.tensor([5, 6, 7, 8, 9, 0, 0, 0, 0, 0])
]

y_data = [
  Nx.tensor(0),
  Nx.tensor(1)
]

# Convert to batched dataset
data =
  Enum.zip(x_data, y_data)
  |> Enum.map(fn {x, y} -> {Nx.stack([x]), Nx.stack([y])} end)

# Define simple feedforward model
model =
  Axon.input("input", shape: {nil, 10})
  |> Axon.embedding(100, 32)      # vocab size 100, embedding dim 32
  |> Axon.mean(axis: 1)
  |> Axon.dense(64, activation: :relu)
  |> Axon.dense(2)                # number of classes

# Create training loop
loop =
  Axon.Loop.trainer(model, :sparse_categorical_cross_entropy, Axon.Optimizers.adam(0.01))
  |> Axon.Loop.metric(:accuracy)

# Train the model
model_state = Axon.Loop.run(loop, data, %{}, epochs: 10)

# Inverse label map
label_map = %{"greeting" => 0, "goodbye" => 1}
inv_label_map = for {k, v} <- label_map, into: %{}, do: {v, k}

# Prediction function
predict = fn input_sentence ->
  encoded =
    input_sentence
    |> String.downcase()
    |> String.split()
    |> Enum.map(&Map.get(vocab, &1, 0))      # fallback to 0 if not found
    |> Enum.take(10)
    |> then(&(&1 ++ List.duplicate(0, 10 - length(&1)))) # pad

  input_tensor = Nx.tensor([encoded])
  pred = Axon.Loop.predict(loop, model_state, input_tensor)
  pred_class = Nx.argmax(pred, axis: 1) |> Nx.to_number()

  IO.puts("→ Input: #{input_sentence}")
  IO.puts("→ Predicted intent: #{inv_label_map[pred_class]}")
end

# Example prediction
predict.("hello there")

