defmodule Core.MiniIntent do
  @moduledoc "Tiny intent model: build, train, save/load, predict."
  require Axon
  require Nx

  @pad 0
  @unk 4
  @vocab %{"hello" => 1, "there" => 2, "hi" => 3, "__UNK__" => @unk, "goodbye" => 5, "now" => 6}
  @vocab_size 100
  @seq_len 10
  @param_path Path.join(:code.priv_dir(:elixir_ai_core), "mini_intent_params.bin")
  @inv_label %{0 => "greeting", 1 => "goodbye"}

  # ---------- Public API ----------
  def start() do
    Nx.global_default_backend(Nx.BinaryBackend)
    ensure_params!()
    :ok
  end

  def predict(sentence, threshold \\ 0.55) do
    {model, params} = {model(), load!()}
    input = Nx.tensor([encode(sentence)], type: :s64)
    pred  = Axon.predict(model, params, %{"input" => input})

    class_id = pred |> Nx.argmax(axis: 1) |> Nx.to_flat_list() |> hd()
    conf =
      pred
      |> Nx.take_along_axis(Nx.tensor([[class_id]], type: :s64), axis: 1)
      |> Nx.reshape({})
      |> Nx.to_number()

    label = if conf < threshold, do: "uncertain", else: @inv_label[class_id]
    {label, conf, class_id}
  end

  # ---------- Internals ----------
  defp ensure_params!() do
    case File.read(@param_path) do
      {:ok, _} -> :ok
      _ ->
        params = train()
        File.mkdir_p!(Path.dirname(@param_path))
        File.write!(@param_path, :erlang.term_to_binary(params))
        :ok
    end
  end

  defp load!() do
    @param_path |> File.read!() |> :erlang.binary_to_term()
  end

  defp encode(s) do
    s
    |> String.downcase()
    |> String.split()
    |> Enum.map(&Map.get(@vocab, &1, @unk))
    |> Enum.take(@seq_len)
    |> then(&(&1 ++ List.duplicate(@pad, max(0, @seq_len - length(&1)))))
  end

  defp data() do
    x = ["hello there", "hi hello there", "goodbye now", "goodbye goodbye now now"]
    y = [
      Nx.tensor([1.0, 0.0]), Nx.tensor([1.0, 0.0]),
      Nx.tensor([0.0, 1.0]), Nx.tensor([0.0, 1.0])
    ]

    inputs = x |> Enum.map(&encode/1) |> Enum.map(&Nx.tensor(&1, type: :s64))
    Enum.zip(inputs, y)
    |> Enum.map(fn {x, y} -> {Nx.reshape(x, {1, @seq_len}), Nx.reshape(y, {1, 2})} end)
    |> Enum.chunk_every(2, 2, :discard)
    |> Enum.map(fn batch ->
      { Nx.concatenate(Enum.map(batch, &elem(&1, 0)), axis: 0),
       Nx.concatenate(Enum.map(batch, &elem(&1, 1)), axis: 0) }
    end)
  end

  defp model() do
    tokens = Axon.input("input", shape: {nil, @seq_len})
    embeds = Axon.embedding(tokens, @vocab_size, 32)

pooled =
  Axon.layer(
    fn emb, toks, _opts ->
      # emb: {b,s,dim}, toks: {b,s}
      mask   = Nx.not_equal(toks, 0)
      mask_f = Nx.as_type(mask, Nx.type(emb))        # f32
      mask_e = Nx.new_axis(mask_f, -1)               # {b,s,1}

      emb_m  = Nx.multiply(emb, mask_e)              # {b,s,dim}
      sum    = Nx.sum(emb_m, axes: [1])              # {b,dim}
      count  = Nx.sum(mask_f, axes: [1])             # {b}

      denom  = Nx.max(count, Nx.tensor(1.0, type: Nx.type(count)))
      Nx.divide(sum, Nx.new_axis(denom, -1))         # {b,dim}
    end,
    [embeds, tokens]
  )

    pooled
    |> Axon.dense(64, activation: :relu)
    |> Axon.dense(2, activation: :softmax)
  end

  defp train() do
    :rand.seed(:exsss, {101, 202, 303})
    m = model()
    loop =
      Axon.Loop.trainer(m, :categorical_cross_entropy, Axon.Optimizers.adam(0.01))
      |> Axon.Loop.metric(:accuracy)

    init = Axon.init(m, %{"input" => Nx.template({1, @seq_len}, :s64)})
    Axon.Loop.run(loop, data(), init, epochs: 100)
  end
end

