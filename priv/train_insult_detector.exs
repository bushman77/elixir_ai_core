# deps: {:nx, "~> 0.9"}, {:axon, "~> 0.7"}, {:jason, "~> 1.4"}
require Axon
require Nx

# Optional: switch to EXLA if available on your box.
if Code.ensure_loaded?(EXLA.Backend), do: Nx.global_default_backend(EXLA.Backend), else: Nx.global_default_backend(Nx.BinaryBackend)

insults_path  = "priv/datasets/grump_insults_5k.jsonl"
neutrals_path = "priv/datasets/grump_neutral_5k.jsonl" # optional; will synthesize if missing

# ────────────────────────────────────────────────────────────────────────────────
# 1) Load datasets
defmodule DS do
  def load_jsonl(path) do
    File.stream!(path, [], :line)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&Jason.decode!/1)  # each line: %{"text" => "...", "label" => "..."}
    |> Enum.to_list()
  end

  def maybe_mock_neutrals(n) do
    # quick neutral generator (safe & boring)
    opens = ~w(hey hello hi okay alright btw fyi just quick note)
    verbs = ~w(checking sharing noting confirming asking getting trying)
    objs  = ~w(update details status idea plan build code link)
    tails = [
      "what do you think?",
      "when you have a minute.",
      "thanks!",
      "let me know.",
      "for later.",
      "no rush.",
      "just curious."
    ]

    for _ <- 1..n do
      text = [Enum.random(opens), Enum.random(verbs), "a", Enum.random(objs), Enum.random(tails)]
             |> Enum.join(" ")

      %{"text" => text, "label" => "neutral"}
    end
  end
end

insults  = DS.load_jsonl(insults_path)
neutrals = if File.exists?(neutrals_path), do: DS.load_jsonl(neutrals_path), else: DS.maybe_mock_neutrals(length(insults))

# Balance & shuffle
min_n = min(length(insults), length(neutrals))

data_all =
  insults |> Enum.take(min_n)
  |> Enum.concat(Enum.take(neutrals, min_n))
  |> Enum.shuffle()

IO.puts("Loaded #{length(insults)} insults, #{length(neutrals)} neutrals → using #{min_n} each.")

# ────────────────────────────────────────────────────────────────────────────────
# 2) Vocab + encoding
pad_id  = 0
unk_id  = 1
max_len = 16

tokenize = fn s ->
  s
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9\s']/u, " ")
  |> String.split()
end

all_tokens =
  data_all
  |> Enum.flat_map(fn %{"text" => t} -> tokenize.(t) end)
  |> Enum.uniq()
  |> Enum.sort()

vocab =
  all_tokens
  |> Enum.with_index(2)
  |> Map.new(fn {w, i} -> {w, i} end)
  |> Map.put("<unk>", unk_id)

vocab_size = (vocab |> Map.values() |> Enum.max()) + 1

encode = fn s ->
  s
  |> tokenize.()
  |> Enum.map(&Map.get(vocab, &1, unk_id))
  |> Enum.take(max_len)
  |> then(&(&1 ++ List.duplicate(pad_id, max_len - length(&1))))
end

classes = ["neutral", "insult"]

label_to_onehot = fn
  "neutral" -> Nx.tensor([1.0, 0.0])
  "insult"  -> Nx.tensor([0.0, 1.0])
end

# ────────────────────────────────────────────────────────────────────────────────
# 3) Build examples (pairs) and constant-size batches (Option A: discard tail)
batch_size = 32

examples =
  data_all
  |> Enum.map(fn %{"text" => t, "label" => y} ->
    x = Nx.tensor([encode.(t)], type: :s64)  # {1, max_len}
    y = Nx.reshape(label_to_onehot.(y), {1, 2})
    {x, y}
  end)

steps_per_epoch = div(length(examples), batch_size)  # tail is discarded
IO.puts("🧮 batch_size=#{batch_size}  steps/epoch=#{steps_per_epoch}")

to_batches = fn pairs ->
  pairs
  |> Stream.chunk_every(batch_size, batch_size, :discard)   # <-- discard remainder
  |> Stream.map(fn chunk ->
    xs = Enum.map(chunk, &elem(&1, 0)) |> Nx.concatenate(axis: 0) # {b, max_len}
    ys = Enum.map(chunk, &elem(&1, 1)) |> Nx.concatenate(axis: 0) # {b, 2}
    {xs, ys}
  end)
end

data_stream = to_batches.(examples)

# ────────────────────────────────────────────────────────────────────────────────
# 4) Model (masked mean pool)
tokens = Axon.input("input", shape: {nil, max_len})
embeds = Axon.embedding(tokens, vocab_size, 64)

pooled =
  Axon.layer(
    fn emb, toks, _opts ->
      mask   = Nx.not_equal(toks, pad_id)
      mask_f = Nx.as_type(mask, Nx.type(emb))
      emb_m  = Nx.multiply(emb, Nx.new_axis(mask_f, -1))
      sum    = Nx.sum(emb_m, axes: [1])
      count  = Nx.sum(mask_f, axes: [1])
      denom  = Nx.max(count, Nx.tensor(1.0, type: Nx.type(count)))
      Nx.divide(sum, Nx.new_axis(denom, -1))
    end,
    [embeds, tokens]
  )

model =
  pooled
  |> Axon.dense(128, activation: :relu)
  |> Axon.dropout(rate: 0.1)
  |> Axon.dense(2, activation: :softmax)

loop =
  Axon.Loop.trainer(model, :categorical_cross_entropy, Axon.Optimizers.adam(0.001))
  |> Axon.Loop.metric(:accuracy)

init_state = Axon.init(model, %{"input" => Nx.template({1, max_len}, :s64)})

epochs = 6
IO.puts("🚀 training for #{epochs} epochs (total batches ≈ #{steps_per_epoch * epochs})")

{μs, params} =
  :timer.tc(fn ->
    Axon.Loop.run(loop, data_stream, init_state, epochs: epochs)
  end)

secs = μs / 1_000_000
IO.puts("⏱️ training time: #{Float.round(secs, 2)} s")

# ────────────────────────────────────────────────────────────────────────────────
# 5) Save artifacts
File.mkdir_p!("priv/models/grump/v1")
File.write!("priv/models/grump/v1/params.bin", :erlang.term_to_binary(params))
File.write!("priv/models/grump/v1/vocab.json", Jason.encode!(vocab))
File.write!("priv/models/grump/v1/meta.json", Jason.encode!(%{
  classes: classes,
  max_len: max_len,
  pad_id: pad_id,
  unk_id: unk_id,
  vocab_size: vocab_size,
  epochs: epochs,
  batch_size: batch_size
}))

IO.puts("💾 saved → priv/models/grump/v1/{params.bin,vocab.json,meta.json}")

# ────────────────────────────────────────────────────────────────────────────────
# 6) Sanity check
predict = fn sentence ->
  x = Nx.tensor([encode.(sentence)], type: :s64)
  pred = Axon.predict(model, params, %{"input" => x})
  class_id = pred |> Nx.argmax(axis: 1) |> Nx.to_flat_list() |> hd()
  conf = pred
         |> Nx.take_along_axis(Nx.tensor([[class_id]], type: :s64), axis: 1)
         |> Nx.reshape({}) |> Nx.to_number()
  {Enum.at(classes, class_id), conf}
end

for s <- [
  "Look, your plan is a duct-taped prototype with glitter.",
  "hello there how are you today",
  "bold move, that argument is a merge conflict with opinions"
] do
  {lbl, c} = predict.(s)
  IO.puts("“#{s}” → #{lbl} (#{Float.round(c*100, 1)}%)")
end

