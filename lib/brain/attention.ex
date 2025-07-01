defmodule Brain.Attention do
  import Nx.Defn

  defn softmax(tensor) do
    shifted = tensor - Nx.reduce_max(tensor, axes: [-1], keep_axes: true)
    exps = Nx.exp(shifted)
    exps / Nx.sum(exps, axes: [-1], keep_axes: true)
  end

  defn scaled_dot_product(q, k, v, dopamine_level \\ 1.0) do
    dk = Nx.shape(k) |> elem(1) |> Nx.sqrt()
    scores = Nx.dot(q, [1], Nx.transpose(k), [0]) / dk
    weights = softmax(scores * dopamine_level)
    Nx.dot(weights, v)
  end

  defn debug_softmax(q, k, dopamine_level) do
    dk = Nx.shape(k) |> elem(1) |> Nx.sqrt()
    scores = Nx.dot(q, [1], Nx.transpose(k), [0]) / dk
    weights = softmax(scores * dopamine_level)
    %{scores: scores, weights: weights}
  end
end
