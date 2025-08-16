defmodule Core.IntentPOSProfile do
  @moduledoc "POS prototypes per intent + scoring."
  @tags [:noun, :verb, :adj, :adv, :pron, :det, :aux, :adp, :conj, :num, :part, :intj, :punct]
  @alpha 0.10  # EMA rate; tune 0.05–0.2

  # In-memory store (swap with DB if you want persistence)
  @table :intent_pos_profiles

  def start_link(_ \\ []) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    load_defaults()
    {:ok, self()}
  end

  def tags, do: @tags

  def load_defaults() do
    # conservative flat priors so nothing is zero
    prior = List.duplicate(1.0 / length(@tags), length(@tags))
    for intent <- [:greeting, :question, :how_to, :troubleshoot, :request, :confirm, :thanks, :goodbye, :insult, :unknown] do
      :ets.insert(@table, {intent, prior})
    end
  end

  def get(intent) do
    case :ets.lookup(@table, intent) do
      [{^intent, vec}] -> vec
      _ -> List.duplicate(1.0 / length(@tags), length(@tags))
    end
  end

  # Update with EMA: new = (1-α)*old + α*obs; then renormalize
  def observe(intent, pos_hist_vec) when is_list(pos_hist_vec) do
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
    proto = get(intent)
    cosine(proto, pos_hist_vec)
  end

  defp normalize(vec) do
    sum = Enum.sum(vec)
    if sum <= 0, do: List.duplicate(1.0 / length(vec), length(vec)),
      else: Enum.map(vec, &(&1 / sum))
  end

  defp cosine(a, b) do
    dot = Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    mag = :math.sqrt(Enum.reduce(a, 0.0, &(&1*&1 + &2))) * :math.sqrt(Enum.reduce(b, 0.0, &(&1*&1 + &2)))
    if mag == 0.0, do: 0.0, else: dot / mag
  end
end

