defmodule FRP.Pipeline do
  @moduledoc """
  One function to:
    - Build features from %SemanticInput{}
    - Run FRP model predict
    - Pick bucket + sliders
    - Return updated SemanticInput with :style, :bucket, :uncertainty
  """

  alias FRP.{Features, Labels, Model}

  @buckets Labels.buckets()

  @doc """
  params: trained Axon params (state.model_state)
  opts can include history: %{last_user_intent: ..., last_bucket: ...}
  """
  def attach(sem, params, opts \\ []) do
    {x, _meta} = Features.build(sem, opts)

    pred = Model.predict(params, x)
    reg = pred["reg"] |> to_list1()
    logits = pred["logits"] |> to_list1()

    {bucket_ix, confidence} = argmax_with_conf(logits)
    bucket = Enum.at(@buckets, bucket_ix) || :concise

    sliders = %{
      hedge: reg |> Enum.at(0),
      warmth: reg |> Enum.at(1),
      formality: reg |> Enum.at(2),
      directness: reg |> Enum.at(3),
      humor: reg |> Enum.at(4),
      empathy: reg |> Enum.at(5),
      grumpiness: reg |> Enum.at(6)
    }

    sem
    |> Map.put(:frp_bucket, bucket)
    |> Map.put(:frp_sliders, sliders)
    |> Map.put(:frp_uncertainty, 1.0 - confidence)
  end

  defp to_list1(t) do
    t |> Nx.to_flat_list()
  end

  defp argmax_with_conf(logits) do
    exps = logits |> Enum.map(&:math.exp/1)
    z = Enum.sum(exps)
    probs = Enum.map(exps, &(&1 / z))
    {ix, p} =
      probs
      |> Enum.with_index()
      |> Enum.max_by(fn {p, _i} -> p end)
      |> then(fn {p, i} -> {i, p} end)

    {ix, p}
  end
end

