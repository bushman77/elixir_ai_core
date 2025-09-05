Nx.default_backend(Nx.BinaryBackend)

alias ML.Reranker
alias ML.Data.JSONLLoader

path = System.get_env("RERANK_PATH", "priv/data/grumpy_reranker_5k.jsonl")
batch = String.to_integer(System.get_env("BATCH", "16"))
epochs = String.to_integer(System.get_env("EPOCHS", "2"))
max_len = String.to_integer(System.get_env("MAX_LEN", "384"))
lr = String.to_float(System.get_env("LR", "1.0e-3"))

{model, cfg} = Reranker.model(max_len: max_len)
params = Axon.init(model)

bce = fn y_pred, y_true -> Axon.Losses.binary_cross_entropy(y_true, y_pred) end
opt = Axon.Optimizers.adam(lr)

loop = Axon.Loop.trainer(model, opt, loss_fn: bce)
  |> Axon.Loop.metric(:loss)

data = JSONLLoader.stream_rerank(path, batch, max_len)
state = Axon.Loop.run(loop, data, %{}, epochs: epochs)
:ok = File.mkdir_p!("/tmp/weights")
:ok = File.write!("/tmp/weights/reranker.npz", :erlang.term_to_binary(state[:model_state]))
IO.puts("Saved /tmp/weights/reranker.npz")
