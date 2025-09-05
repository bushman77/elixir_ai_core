defmodule ML.Data.JSONLLoader do
  @moduledoc "Minimal JSONL loader yielding batches for SFT and Reranker."
  alias ML.ByteTokenizer, as: BT

  def stream_sft(path, batch_size, seq_len \\ 512) do
    File.stream!(path)
    |> Stream.map(&Jason.decode!/1)
    |> Stream.map(fn %{"input" => inp, "target" => tgt} ->
      x_ids = truncate(BT.encode(inp, add_bos: true,  add_eos: false), seq_len)
      y_ids = truncate(BT.encode(tgt, add_bos: false, add_eos: true),  seq_len)
      {%{"input_ids" => to_tensor(x_ids, seq_len)}, to_tensor(y_ids, seq_len)}
    end)
    |> batch(batch_size)
  end

  def stream_rerank(path, batch_size, seq_len \\ 512) do
    File.stream!(path)
    |> Stream.map(&Jason.decode!/1)
    |> Stream.map(fn %{"prompt" => p, "candidate" => c, "label" => lab} ->
      ids = truncate(BT.encode(p <> "\n" <> c, add_bos: true, add_eos: true), seq_len)
      y   = Nx.tensor([[lab]], type: :f32) # {1,1}
      {%{"input_ids" => to_tensor(ids, seq_len)}, y}
    end)
    |> batch(batch_size)
  end

  defp to_tensor(ids, seq_len) do
    pad = List.duplicate(0, seq_len - length(ids))
    Nx.tensor(ids ++ pad, type: :s64) |> Nx.reshape({1, seq_len})
  end

  defp truncate(ids, seq_len), do: Enum.take(ids, seq_len)

  defp batch(stream, bs) do
    stream
    |> Stream.chunk_every(bs)
    |> Stream.map(fn chunk ->
      xs = chunk |> Enum.map(&elem(&1, 0)["input_ids"]) |> Nx.concatenate(axis: 0)
      ys = chunk |> Enum.map(&elem(&1, 1))              |> Nx.concatenate(axis: 0)
      {%{"input_ids" => xs}, ys}
    end)
  end
end

