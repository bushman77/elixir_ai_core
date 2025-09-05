defmodule ML.BaseDecoder do
  @moduledoc "Byte-level LM: input_ids -> embedding -> GRU -> vocab logits."
  alias Axon

  def model(opts) do
    vocab   = Keyword.fetch!(opts, :vocab_size)
    seq_len = Keyword.get(opts, :seq_len, 256)
    d_model = Keyword.get(opts, :d_model, 256)
    hidden  = Keyword.get(opts, :hidden, d_model)

    input_ids = Axon.input("input_ids", shape: {nil, seq_len})

    emb = Axon.embedding(input_ids, vocab, d_model, name: "embed")

    # Axon GRU returns {sequence, state}. Take the sequence.
    seq =
      emb
      |> Axon.gru(hidden, name: "gru")
      |> then(fn {out, _state} -> out end)

    Axon.dense(seq, vocab, name: "lm_head")
  end
end

