defmodule Core.MiniIntent do
  @moduledoc "Tiny intent model with retrain + class balancing + stratified validation."
  require Axon
  require Nx
  import Ecto.Query

  alias Core.DB

  @pad "<PAD>"
  @unk "<UNK>"
  @seq_len 32

  @store_dir Path.join(:code.priv_dir(:elixir_ai_core), "mini_intent")
  @param_path Path.join(@store_dir, "params.bin")
  @vocab_path Path.join(@store_dir, "vocab.json")
  @labels_path Path.join(@store_dir, "labels.json")
  @summary_path Path.join(@store_dir, "training_summary.json")

  # ---------- Public ----------
  def start() do
    Nx.global_default_backend(Nx.BinaryBackend)
    File.mkdir_p!(@store_dir)
    :ok
  end

  # Prepare hot state for GenServer: {vocab, labels, model, params}
  def prepare() do
    start()
    vocab = load_vocab!()
    labels = load_labels!()
    {vocab, labels, model(vocab, labels), load_params!()}
  end

  # Inference using preloaded state
  def infer({vocab, labels, model, params}, sentence, threshold \\ 0.55) do
    x = Nx.tensor([encode(sentence, vocab)], type: :s64)
    pred = Axon.predict(model, params, %{"input" => x})
    {id, conf} = top1(pred)
    label = labels |> invert() |> Map.fetch!(id)
    if conf < threshold, do: {"uncertain", conf, id}, else: {label, conf, id}
  end

  # ---------- “Update” commands ----------
  # Retrain from labeled text/intent rows in training_examples table
  def retrain_from_db!(opts \\ []) do
    examples = dataset_from_training_examples(opts)
    retrain_with_examples!(examples, opts)
  end

  # Retrain from Brain-derived pairs, if available.
  # Define Brain.training_pairs/0 -> [%{text: "...", intent: "..."}, ...]
  def retrain_from_brain!(opts \\ []) do
    examples =
      if function_exported?(Brain, :training_pairs, 0) do
        Brain.training_pairs()
      else
        []
      end

    retrain_with_examples!(examples, opts)
  end

  # Core retrain path (shared)
  def retrain_with_examples!(raw_examples, opts \\ []) do
    min_count      = Keyword.get(opts, :min_count, 1)
    max_per_intent = Keyword.get(opts, :max_per_intent, 5_000)
    train_ratio    = Keyword.get(opts, :train_ratio, 0.85)
    batch_size     = Keyword.get(opts, :batch_size, 64)
    epochs         = Keyword.get(opts, :epochs, 8)

    # 1) Clean, de-dup, group
    examples =
      raw_examples
      |> Enum.map(fn %{text: t, intent: i} -> %{text: clean(t), intent: to_string(i)} end)
      |> Enum.reject(fn %{text: t, intent: i} -> t == "" or is_nil(i) end)
      |> uniq_by_text_intent()

    if examples == [] do
      raise "No examples found to retrain."
    end

    # 2) Build labels
    intents = examples |> Enum.map(& &1.intent) |> Enum.uniq() |> Enum.sort()
    label_to_id = intents |> Enum.with_index() |> Map.new()

    # 3) Build vocab (min_count) and cap size
    {vocab, _counts} = build_vocab(examples, min_count: min_count, max_size: 100_000)

    # 4) Balance per intent
    balanced =
      examples
      |> Enum.group_by(& &1.intent)
      |> balance_groups(max_per_intent)

    # 5) Stratified split per intent
    {train_ex, val_ex} = stratified_split(balanced, train_ratio)

    # 6) Encode
    {xtr, ytr} = encode_dataset(train_ex, vocab, label_to_id)
    {xva, yva} = encode_dataset(val_ex, vocab, label_to_id)

    # 7) Train
    {model, params, train_metrics} =
      fit(vocab, label_to_id, xtr, ytr, epochs: epochs, batch_size: batch_size)

    # 8) Evaluate on validation
    val_acc = evaluate_accuracy(model, params, to_batches(xva, yva, batch_size))

    # 9) Persist
    save_vocab!(vocab)
    save_labels!(label_to_id)
    save_params!(params)

    summary = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      counts: Enum.into(Enum.map(balanced |> Enum.group_by(& &1.intent), fn {k, v} -> {k, length(v)} end), %{}),
      intents: intents,
      vocab_size: map_size(vocab),
      seq_len: @seq_len,
      train_size: length(xtr),
      val_size: length(xva),
      epochs: epochs,
      batch_size: batch_size,
      train_metrics: train_metrics,
      val_accuracy: val_acc
    }

    File.write!(@summary_path, Jason.encode!(summary, pretty: true))
    :ok
  end

  # ---------- Data sources ----------
  defp dataset_from_training_examples(opts) do
    min_conf = Keyword.get(opts, :min_conf, 0.75)
    max_per_intent = Keyword.get(opts, :max_per_intent, 5_000)

    from(t in Core.TrainingExample,
      where: t.confidence >= ^min_conf,
      order_by: [desc: t.inserted_at]
    )
    |> DB.all()
    |> Enum.group_by(& &1.intent)
    |> Enum.flat_map(fn {_i, rows} ->
      rows
      |> Enum.uniq_by(&String.downcase(&1.text))
      |> Enum.take(max_per_intent)
    end)
    |> Enum.map(&%{text: &1.text, intent: &1.intent})
  end

  # ---------- Text + vocab ----------
  defp clean(s) do
    s
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s']/u, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp uniq_by_text_intent(list) do
    list
    |> Enum.reduce({MapSet.new(), []}, fn %{text: t, intent: i} = ex, {seen, acc} ->
      key = {t, i}
      if MapSet.member?(seen, key), do: {seen, acc}, else: {MapSet.put(seen, key), [ex | acc]}
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp build_vocab(examples, opts) do
    min_count = Keyword.get(opts, :min_count, 1)
    max_size  = Keyword.get(opts, :max_size, 100_000)

    counts =
      examples
      |> Enum.flat_map(&String.split(&1.text))
      |> Enum.frequencies()

    tokens =
      counts
      |> Enum.filter(fn {_t, c} -> c >= min_count end)
      |> Enum.sort_by(fn {t, c} -> {-c, t} end)
      |> Enum.map(&elem(&1, 0))

    trimmed = Enum.take(tokens, max_size - 2)

    vocab =
      ([@pad, @unk] ++ trimmed)
      |> Enum.with_index()
      |> Map.new()

    {vocab, counts}
  end

  # ---------- Balance + split ----------
  defp balance_groups(groups_map, max_per_intent) do
    # Downsample each intent to the smallest class or max_per_intent
    sizes = groups_map |> Enum.map(fn {_k, v} -> length(v) end)
    min_class = Enum.min(sizes)
    cap = min(min_class, max_per_intent)

    groups_map
    |> Enum.flat_map(fn {_i, rows} ->
      rows
      |> Enum.shuffle()
      |> Enum.take(cap)
    end)
  end

  defp stratified_split(examples, train_ratio) do
    examples
    |> Enum.group_by(& &1.intent)
    |> Enum.reduce({[], []}, fn {_i, rows}, {tr_acc, va_acc} ->
      ntr = floor(length(rows) * train_ratio)
      {tr, va} = rows |> Enum.shuffle() |> Enum.split(ntr)
      {tr ++ tr_acc, va ++ va_acc}
    end)
  end

  # ---------- Encode ----------
  defp encode_dataset(examples, vocab, label_to_id) do
    {x, y} =
      examples
      |> Enum.map(fn %{text: t, intent: lab} ->
        xi = Nx.tensor([encode(t, vocab)], type: :s64)
        yi = one_hot(label_to_id[lab], map_size(label_to_id))
        {xi, yi}
      end)
      |> Enum.unzip()

    {x, y}
  end

  defp encode(s, vocab) do
    ids =
      s
      |> String.split()
      |> Enum.map(&Map.get(vocab, &1, vocab[@unk]))
      |> Enum.take(@seq_len)

    pad_id = vocab[@pad]
    ids ++ List.duplicate(pad_id, max(0, @seq_len - length(ids)))
  end

  defp one_hot(id, n) do
    Nx.equal(Nx.tensor(Enum.to_list(0..(n - 1))), Nx.tensor(id))
    |> Nx.as_type(:f32)
    |> Nx.reshape({1, n})
  end

  # ---------- Model / train / eval ----------
  defp model(vocab, labels) do
    vocab_size = map_size(vocab)
    num_labels = map_size(labels)

    tokens = Axon.input("input", shape: {nil, @seq_len})
    embeds = Axon.embedding(tokens, vocab_size, 64)

    pooled =
      Axon.layer(fn emb, toks, _ ->
        mask = Nx.not_equal(toks, vocab[@pad])
        maskf = Nx.as_type(mask, Nx.type(emb))
        emb_m = emb * Nx.new_axis(maskf, -1)
        sum = Nx.sum(emb_m, axes: [1])
        cnt = Nx.maximum(Nx.sum(maskf, axes: [1]), Nx.tensor(1.0))
        sum / Nx.new_axis(cnt, -1)
      end, [embeds, tokens])

    pooled
    |> Axon.dropout(rate: 0.1)
    |> Axon.dense(128, activation: :relu)
    |> Axon.dense(num_labels, activation: :softmax)
  end

  defp fit(vocab, labels, inputs, targets, opts) do
    epochs = Keyword.get(opts, :epochs, 8)
    bs     = Keyword.get(opts, :batch_size, 64)

    m = model(vocab, labels)
    loop =
      Axon.Loop.trainer(m, :categorical_cross_entropy, Axon.Optimizers.adam(0.001))
      |> Axon.Loop.metric(:accuracy)

    init = Axon.init(m, %{"input" => Nx.template({1, @seq_len}, :s64)})

    params =
      Axon.Loop.run(loop, to_batches(inputs, targets, bs), init, epochs: epochs)

    # Basic train metrics we can report (final accuracy on last epoch is tracked internally),
    # we’ll just echo config here; deeper metrics require reporters.
    train_metrics = %{epochs: epochs, batch_size: bs}
    {m, params, train_metrics}
  end

  defp to_batches(inputs, targets, bs) do
    total = length(inputs)

    Stream.unfold(0, fn i ->
      if i >= total do
        nil
      else
        xs =
          inputs
          |> Enum.slice(i, bs)
          |> Nx.concatenate(axis: 0)

        ys =
          targets
          |> Enum.slice(i, bs)
          |> Nx.concatenate(axis: 0)

        {{xs, ys}, i + bs}
      end
    end)
  end

  defp evaluate_accuracy(model, params, batch_stream) do
    {correct, total} =
      Enum.reduce(batch_stream, {0, 0}, fn {x, y}, {acc_c, acc_t} ->
        pred = Axon.predict(model, params, %{"input" => x})
        py = Nx.argmax(pred, axis: 1)
        yy = Nx.argmax(y, axis: 1)
        c = Nx.equal(py, yy) |> Nx.as_type(:s64) |> Nx.sum() |> Nx.to_number()
        t = Nx.axis_size(y, 0)
        {acc_c + c, acc_t + t}
      end)

    if total == 0, do: 0.0, else: correct / total
  end

  defp top1(pred) do
    id = pred |> Nx.argmax(axis: 1) |> Nx.to_flat_list() |> hd()
    conf =
      pred
      |> Nx.take_along_axis(Nx.tensor([[id]], type: :s64), axis: 1)
      |> Nx.reshape({})
      |> Nx.to_number()

    {id, conf}
  end

  # ---------- Persist ----------
  defp invert(map), do: for({k, v} <- map, into: %{}, do: {v, k})

  defp load_params!(), do: @param_path |> File.read!() |> :erlang.binary_to_term()
  defp save_params!(params), do: File.write!(@param_path, :erlang.term_to_binary(params))

  defp load_vocab!(), do: @vocab_path |> File.read!() |> Jason.decode!()
  defp save_vocab!(vocab), do: File.write!(@vocab_path, Jason.encode!(vocab))

  defp load_labels!(), do: @labels_path |> File.read!() |> Jason.decode!()
  defp save_labels!(labels), do: File.write!(@labels_path, Jason.encode!(labels))
end

