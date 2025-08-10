# deps: {:nx, "~> 0.9"}, {:axon, "~> 0.7"}
require Axon
require Nx

Nx.global_default_backend(Nx.BinaryBackend)

# --- Vocab ---
vocab = %{"hello" => 1, "there" => 2, "hi" => 3, "goodbye" => 5, "now" => 6}
pad_id = 0

# --- Encode helper (fixed length 10) ---
encode = fn s ->
  s
  |> String.downcase()
  |> String.split()
  |> Enum.map(&Map.get(vocab, &1, pad_id))
  |> Enum.take(10)
  |> then(&(&1 ++ List.duplicate(pad_id, 10 - length(&1))))
end

# --- Training data: short + long variants for both classes ---
x_sentences = [
  "hello there",                # greeting (short)
  "hi hello there",             # greeting (long)
  "goodbye now",                # goodbye (short)
  "goodbye goodbye now now"     # goodbye (long)
]

y_onehots = [
  Nx.tensor([1.0, 0.0]),
  Nx.tensor([1.0, 0.0]),
  Nx.tensor([0.0, 1.0]),
  Nx.tensor([0.0, 1.0])
]

inputs =
  x_sentences
  |> Enum.map(encode)
  |> Enum.map(&Nx.tensor(&1, type: :s64))

data =
  Enum.zip(inputs, y_onehots)
  |> Enum.map(fn {x, y} -> {Nx.reshape(x, {1, 10}), Nx.reshape(y, {1, 2})} end)

# --- Model: embedding + MASKED mean pooling (ignore PAD=0) ---
tokens = Axon.input("input", shape: {nil, 10})
embeds = Axon.embedding(tokens, 100, 32)  # same as tokens |> Axon.embedding(...)

pooled =
  Axon.layer(
    fn emb, toks, _opts ->
      # emb: {b,s,dim}, toks: {b,s}
      mask   = Nx.not_equal(toks, 0)                          # {b,s} u8
      mask_f = Nx.as_type(mask, Nx.type(emb))                 # -> f32
      mask_e = Nx.new_axis(mask_f, -1)                        # {b,s,1}
      emb_m  = Nx.multiply(emb, mask_e)                       # {b,s,dim}

      sum    = Nx.sum(emb_m, axes: [1])                       # {b,dim}
      count  = Nx.sum(mask_f, axes: [1])                      # {b} f32
      # ↓ use Nx.max and match dtype
      denom  = Nx.max(count, Nx.tensor(1.0, type: Nx.type(count)))
      Nx.divide(sum, Nx.new_axis(denom, -1))                  # {b,dim}
    end,
    [embeds, tokens]
  )

model =
  pooled
  |> Axon.dense(64, activation: :relu)
  |> Axon.dense(2, activation: :softmax)

# --- Trainer ---
loop =
  Axon.Loop.trainer(model, :categorical_cross_entropy, Axon.Optimizers.adam(0.01))
  |> Axon.Loop.metric(:accuracy)

init_state = Axon.init(model, %{"input" => Nx.template({1, 10}, :s64)})
params = Axon.Loop.run(loop, data, init_state, epochs: 30)

inv_label_map = %{0 => "greeting", 1 => "goodbye"}

# --- Prediction (no default args in anonymous fns) ---
predict = fn sentence, threshold ->
  encoded = encode.(sentence)
  input = Nx.tensor([encoded], type: :s64)

  pred = Axon.predict(model, params, %{"input" => input})

  class_id =
    pred
    |> Nx.argmax(axis: 1)
    |> Nx.to_flat_list()
    |> hd()

  conf =
    pred
    |> Nx.take_along_axis(Nx.tensor([[class_id]], type: :s64), axis: 1)
    |> Nx.reshape({})
    |> Nx.to_number()

  label = if conf < threshold, do: "uncertain", else: inv_label_map[class_id]

  IO.puts("→ Input: #{sentence}")
  IO.puts("→ Predicted intent: #{label} (confidence: #{Float.round(conf * 100.0, 1)}%)")
end

# Convenience wrapper with default threshold
predict_auto = fn sentence -> predict.(sentence, 0.55) end

# --- Tests ---
predict_auto.("hello there")
predict_auto.("goodbye now")
predict_auto.("hi")
predict_auto.("goodbye goodbye")

