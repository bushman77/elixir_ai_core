defmodule Core.IntentPOSProfile do
  @moduledoc "POS prototypes per intent + scoring."
  @tags    [:noun, :verb, :adj, :adv, :pron, :det, :aux, :adp, :conj, :num, :part, :intj, :punct]
  @intents [:greeting, :question, :how_to, :troubleshoot, :request, :confirm, :thanks, :goodbye, :insult, :unknown]
  @alpha 0.10
  @table :intent_pos_profiles

  # --- Public API -------------------------------------------------------------
  def tags,    do: @tags
  def intents, do: @intents

  def get(intent) do
    ensure_table!()
    case :ets.lookup(@table, intent) do
      [{^intent, vec}] -> vec
      _ -> prior()
    end
  end

  # Update with EMA: new = (1-α)*old + α*obs; then renormalize
  def observe(intent, pos_hist_vec) when is_list(pos_hist_vec) do
    ensure_table!()
    old = get(intent)
    blended =
      old
      |> Enum.zip(pos_hist_vec)
      |> Enum.map(fn {o, x} -> (1.0 - @alpha) * o + @alpha * x end)
      |> normalize()

    :ets.insert(@table, {intent, blended})
    :ok
  end

  def score(pos_hist_vec, intent) do
    ensure_table!()
    cosine(get(intent), pos_hist_vec)
  end

  # --- Internals --------------------------------------------------------------
  defp ensure_table!() do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true])
        load_defaults()
        :ok
      _ -> :ok
    end
  end

  defp load_defaults() do
    p = prior()
    Enum.each(@intents, fn intent -> :ets.insert(@table, {intent, p}) end)
  end

  defp prior(), do: List.duplicate(1.0 / length(@tags), length(@tags))

  defp normalize(vec) do
    sum = Enum.sum(vec)
    if sum <= 0, do: prior(), else: Enum.map(vec, &(&1 / sum))
  end

  defp cosine(a, b) do
    dot = Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    mag = :math.sqrt(Enum.reduce(a, 0.0, &(&1*&1 + &2))) * :math.sqrt(Enum.reduce(b, 0.0, &(&1*&1 + &2)))
    if mag == 0.0, do: 0.0, else: dot / mag
  end
end

