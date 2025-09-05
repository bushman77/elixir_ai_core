defmodule ML.Reranker do
  @moduledoc """
  Tiny cross-encoder: (prompt||candidate) → probability in [0,1].

  Simplicity > cleverness: embed → mean-pool → MLP → sigmoid.
  No RNN needed; it’s fast and stable on CPU.
  """
  alias Axon

  @doc """
  Options:
    * :vocab_size (required) — size of your token space
    * :seq_len (default 256) — max sequence length
    * :d_model (default 256) — embedding/hidden width
  """
  def model(opts) do
    vocab = Keyword.fetch!(opts, :vocab_size)
    seq_len = Keyword.get(opts, :seq_len, 256)
    d_model = Keyword.get(opts, :d_model, 256)

    input_ids = Axon.input("input_ids", shape: {nil, seq_len})

    embed =
      Axon.embedding(input_ids, vocab, d_model, name: "embed")

    # Global mean pool across the time axis (axis 1)
    pooled =
      Axon.nx(embed, fn t -> Nx.mean(t, axes: [1]) end)

    pooled
    |> Axon.dense(d_model, activation: :relu, name: "ff1")
    |> Axon.dropout(rate: 0.1)
    |> Axon.dense(1, name: "score")
    |> Axon.sigmoid(name: "prob")
  end
end

