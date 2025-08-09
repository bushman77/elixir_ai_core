#Mix.install([
#  {:axon, "~> 0.6.1"},
#  {:nx, "~> 0.6.4"}
#])

Nx.global_default_backend(Nx.BinaryBackend)

alias Axon
require Nx

# --- Simulated Training Data ---
x_data = [
  Nx.tensor([1, 2, 3, 4, 0, 0, 0, 0, 0, 0]),  # "hello there"
  Nx.tensor([5, 6, 7, 8, 9, 0, 0, 0, 0, 0])   # "goodbye now"
]

# One-hot labels for 2 intents: 0 = greeting, 1 = goodbye
y_data = [
  Nx.tensor([1.0, 0.0]),  # greeting
  Nx.tensor([0.0, 1.0])   # goodbye
]

# --- Zip and Batch ---
data =
  Enum.zip(x_data, y_data)
  |> Enum.map(fn {x, y} -> {Nx.stack([x]), Nx.stack([y])} end)

# --- Model Definition ---
model =
  Axon.input("input", shape: {nil, 10})
  |> Axon.embedding(100, 32)
  |> then(fn layer ->
    Axon.layer(fn input, _opts -> Nx.mean(input, axes: [1]) end, [layer])
  end)
  |> Axon.dense(64, activation: :relu)
  |> Axon.dense(2)

# --- Trainer Loop ---
loop =
  Axon.Loop.trainer(model, :categorical_cross_entropy, Axon.Optimizers.adam(0.01))
  |> Axon.Loop.metric(:accuracy)

# --- Train the Model ---
model_state = Axon.Loop.run(loop, data, %{}, epochs: 10)

# --- Label Map ---
label_map = %{"greeting" => 0, "goodbye" => 1}
inv_label_map = for {k, v} <- label_map, into: %{}, do: {v, k}

# --- Vocabulary ---
vocab = %{
  "hello" => 1,
  "there" => 2,
  "hi" => 3,
  "bye" => 4,
  "goodbye" => 5,
  "now" => 6
}

# --- Prediction Function ---
predict = fn input_sentence ->
  encoded =
    input_sentence
    |> String.downcase()
    |> String.split()
    |> Enum.map(&Map.get(vocab, &1, 0))
    |> Enum.take(10)
    |> then(&(&1 ++ List.duplicate(0, 10 - length(&1))))

  input_tensor = Nx.tensor([encoded])

  # Proper prediction call
  pred = Axon.Loop.predict(loop, model_state, input_tensor)
  pred_class = Nx.argmax(pred, axis: 1) |> Nx.to_number()

  IO.puts("→ Input: #{input_sentence}")
  IO.puts("→ Predicted intent: #{inv_label_map[pred_class]}")
end

# --- Test Prediction ---
predict.("hello there")
predict.("goodbye now")

