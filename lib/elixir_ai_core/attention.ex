defmodule ElixirAiCore.Attention do
  @moduledoc """
  Self-attention mechanism (single-head) using pure Elixir tensors.

  Applies Q/K/V projections and computes output from attention weights.
  """

  alias ElixirAiCore.Tensor

  @doc """
  Perform self-attention on input tensor using weights.

  ## Parameters
    - input: list of token vectors (seq_len x dim)
    - wq/wk/wv: projection matrices (dim x dim)

  ## Returns
    - list of output vectors (seq_len x dim)
  """
  def self_attention(input, wq, wk, wv) do
    q = Tensor.matmul(input, wq)
    k = Tensor.matmul(input, wk)
    v = Tensor.matmul(input, wv)

    scores = Tensor.matmul(q, Tensor.transpose(k))

    d_k = length(List.first(k)) |> :math.sqrt()
    scaled_scores = Tensor.map(scores, &(&1 / d_k))

    # Apply softmax row-wise to scores
    weights =
      Enum.map(scaled_scores, fn row ->
        Tensor.softmax(row)
      end)

    Tensor.matmul(weights, v)
  end
end
