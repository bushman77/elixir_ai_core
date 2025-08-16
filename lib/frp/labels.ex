defmodule FRP.Labels do
  @moduledoc """
  Bootstrap labels from SemanticInput + MoodCore snapshot.
  Produces: %{reg: [7 floats 0..1], cls: int 0..6}
  """

  @buckets [:concise, :step_by_step, :coaching, :exploratory, :corrective, :refusal_soft, :refusal_hard]
  @bucket_ix Enum.with_index(@buckets) |> Enum.into(%{})

  def buckets(), do: @buckets
  def bucket_to_ix(atom), do: Map.fetch!(@bucket_ix, atom)

  def from_semantic(%{sentence: s, intent: intent, confidence: conf} = sem) do
    text = s || ""
    conf = conf || 0.0
    lc = String.downcase(text)

    # crude signals
    q = String.contains?(lc, ["?", "how ", "what ", "why ", "where ", "which "])
    longish = String.split(lc) |> length() > 18
    slang = String.contains?(lc, ["lol", "lmao", "nah", "gonna", "yep", "nope"])
    negative = String.contains?(lc, ["stupid", "hate", "wtf", "broken", "doesn't", "can't"])

    # choose bucket
    bucket =
      cond do
        Map.get(sem, :safety) == :block -> :refusal_hard
        Map.get(sem, :safety) == :soft  -> :refusal_soft
        q or intent in [:how_to, :troubleshoot] -> :step_by_step
        negative -> :corrective
        longish -> :exploratory
        true -> :concise
      end

    {:ok, mood} =
      case safe(MoodCore, :snapshot, []) do
        {:ok, m} -> {:ok, m}
        _ -> {:ok, %{dopamine: 0.5, serotonin: 0.5, valence: 0.5, arousal: 0.5, grumpiness: 0.0}}
      end

    # sliders (0..1)
    hedge = clamp(1.0 - conf) * 0.6 + (q && 0.2 || 0.0)
    warmth = clamp(mood.serotonin * 0.8 + 0.1)
    formality = clamp((slang && 0.2 || 0.6) - (mood.grumpiness * 0.2))
    directness = clamp((intent in [:confirm, :request] && 0.9 || 0.6) + (1.0 - hedge) * 0.2)
    humor = clamp(0.2 + (mood.dopamine - 0.5) * 0.3)
    empathy = clamp(0.4 + (negative && 0.3 || 0.0) + (mood.serotonin - 0.5) * 0.4)
    grump = clamp(mood.grumpiness)

    %{
      reg: [hedge, warmth, formality, directness, humor, empathy, grump],
      cls: bucket_to_ix(bucket)
    }
  end

  defp clamp(x), do: x |> max(0.0) |> min(1.0)
  defp safe(mod, fun, args) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, fun, length(args)) do
      try do
        {:ok, apply(mod, fun, args)}
      rescue
        _ -> :error
      end
    else
      :error
    end
  end
end

