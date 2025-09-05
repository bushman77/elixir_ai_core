Nx.default_backend(Nx.BinaryBackend)

alias ML.{BaseDecoder, ByteTokenizer}
alias ML.Data.JSONLLoader

sft_path = System.get_env("SFT_PATH", "priv/data/grumpy_sft_seed_1k.jsonl")
batch    = String.to_integer(System.get_env("BATCH", "8"))
epochs   = String.to_integer(System.get_env("EPOCHS", "2"))
seq_len  = String.to_integer(System.get_env("SEQ_LEN", "512"))
lr       = String.to_float(System.get_env("LR", "1.0e-3"))

model = ML.BaseDecoder.model(vocab_size: ByteTokenizer.vocab_size(), seq_len: seq_len)

loss = fn y_pred, y_true ->
  Axon.Losses.sparse_categorical_cross_entropy(y_true, y_pred, logits: true)
end

opt  = Axon.Optimizers.adam(lr)
loop = Axon.Loop.trainer(model, opt, loss_fn: loss) |> Axon.Loop.metric(:loss)

data  = JSONLLoader.stream_sft(sft_path, batch, seq_len)
state = Axon.Loop.run(loop, data, %{}, epochs: epochs)

File.mkdir_p!("/tmp/weights")
File.write!("/tmp/weights/base_lm.npz", :erlang.term_to_binary(state[:model_state]))
IO.puts("Saved /tmp/weights/base_lm.npz")

