defmodule ML.Generator do
  @moduledoc """
  Text generation with top-p (nucleus) sampling, temperature, and stop sequences.
  """
  alias ML.{ByteTokenizer, BaseDecoder}
  require Logger

  def generate(prompt, params, opts \\ []) do
    top_p = Keyword.get(opts, :top_p, 0.9)
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_new = Keyword.get(opts, :max_new_tokens, 128)
    stops = Keyword.get(opts, :stops, ["</eos>", "\nuser:"])

    {model, cfg} = BaseDecoder.model()

    ctx_ids = ByteTokenizer.encode(prompt, add_bos: true, add_eos: false)
    ids = do_sample(model, params, ctx_ids, top_p, temperature, max_new, cfg.max_len, stops)
    ByteTokenizer.decode(ids)
  end

  defp do_sample(model, params, ctx_ids, top_p, temperature, max_new, max_len, stops) do
    # Rolling context
    Enum.reduce_while(1..max_new, ctx_ids, fn _step, acc ->
      input_ids = acc |> Enum.take(-max_len)
      x = to_tensor(input_ids, max_len)
      logits = Axon.predict(model, params, x)
      # logits shape: {1, T, V}; take last time step
      last = logits |> Nx.slice([0, -1, 0], [1, 1, Nx.axis_size(logits, 2)]) |> Nx.squeeze()
      next_id = sample_token(last, top_p, temperature)
      new = acc ++ [next_id]
      text = ML.ByteTokenizer.decode(new)
      if Enum.any?(stops, &String.contains?(text, &1)), do: {:halt, new}, else: {:cont, new}
    end)
  end

  defp to_tensor(ids, max_len) do
    pad = List.duplicate(0, max_len - length(ids))
    Nx.tensor((ids ++ pad), type: :s64) |> Nx.reshape({1, max_len})
  end

  defp sample_token(logits, top_p, temperature) do
    # temperature
    logits = Nx.divide(logits, temperature)
    # softmax to probs
    probs = Nx.exp(logits) / Nx.sum(Nx.exp(logits))
    # nucleus filter
    {sorted, idx} = Nx.sort(probs, direction: :descending, return_indices: true)
    csum = Nx.cumulative_sum(sorted)
    mask = Nx.less_equal(csum, top_p)
    k = mask |> Nx.argmax() |> Nx.to_number()
    k = max(k, 1)
    kept = sorted |> Nx.slice([0], [k])
    kept_idx = idx |> Nx.slice([0], [k])
    kept = kept / Nx.sum(kept)
    # sample
    u = :rand.uniform()
    cdf = Nx.cumulative_sum(kept)
    choice_pos = Nx.to_number(Nx.argmax(Nx.greater_equal(cdf, u)))
    Nx.to_number(kept_idx[choice_pos])
  end
end
