defmodule ML.GrumpModel do
  @moduledoc "Neutral vs Insult detector — inference only."
  require Axon
  require Nx

  @on_load :_ensure_backend
  def _ensure_backend do
    Nx.global_default_backend(Nx.BinaryBackend) # phone-safe default
    :ok
  end

  @dir         Application.app_dir(:elixir_ai_core, "priv/models/grump/v1")
  @params_path Path.join(@dir, "params.bin")
  @vocab_path  Path.join(@dir, "vocab.json")
  @meta_path   Path.join(@dir, "meta.json")

  def predict(sentence) when is_binary(sentence) do
    %{model: model, params: params, vocab: vocab, meta: m} = ensure_loaded()
    x =
      sentence
      |> encode(vocab, m["max_len"], m["unk_id"], m["pad_id"])
      |> then(&Nx.tensor([&1], type: :s64))

    pred = Axon.predict(model, params, %{"input" => x})
    class_id = pred |> Nx.argmax(axis: 1) |> Nx.to_flat_list() |> hd()

    conf =
      pred
      |> Nx.take_along_axis(Nx.tensor([[class_id]], type: :s64), axis: 1)
      |> Nx.reshape({})
      |> Nx.to_number()

    {Enum.at(m["classes"], class_id), conf}
  end

  # — internals —

  defp ensure_loaded do
    case :persistent_term.get({__MODULE__, :state}, :undefined) do
      :undefined ->
        meta  = @meta_path  |> File.read!() |> Jason.decode!()
        vocab = @vocab_path |> File.read!() |> Jason.decode!()
        params = @params_path |> File.read!() |> :erlang.binary_to_term()
        vocab_size = (vocab |> Map.values() |> Enum.max()) + 1
        model = build_model(vocab_size, meta["max_len"], meta["pad_id"])
        state = %{model: model, params: params, vocab: vocab, meta: meta}
        :persistent_term.put({__MODULE__, :state}, state)
        state
      s -> s
    end
  end

  defp build_model(vocab_size, max_len, pad_id) do
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

    pooled
    |> Axon.dense(128, activation: :relu)
    |> Axon.dense(2,   activation: :softmax)
  end

  defp encode(sentence, vocab, max_len, unk_id, pad_id) do
    sentence
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s']/u, " ")
    |> String.split()
    |> Enum.map(&Map.get(vocab, &1, unk_id))
    |> Enum.take(max_len)
    |> then(&(&1 ++ List.duplicate(pad_id, max_len - length(&1))))
  end
end

