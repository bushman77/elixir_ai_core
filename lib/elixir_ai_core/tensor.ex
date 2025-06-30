# lib/elixir_ai_core/tensor.ex
defmodule ElixirAiCore.Tensor do
  @moduledoc """
  Lightweight tensor operations in pure Elixir for LLM inference.

  Supports basic vector and matrix ops:
  - dot product
  - matrix multiplication
  - transpose
  - element-wise map
  - bias addition with broadcasting
  - activations: relu, softmax

  Designed to be CPU-friendly and easy to extend.
  """

  @type tensor :: number() | [tensor()]

  @doc """
  Dot product of two vectors (lists of numbers).

  ## Examples

      iex> ElixirAiCore.Tensor.dot([1, 2, 3], [4, 5, 6])
      32
  """
  def dot(a, b) when is_list(a) and is_list(b) do
    Enum.zip(a, b)
    |> Enum.map(fn {x, y} -> x * y end)
    |> Enum.sum()
  end

  @doc """
  Matrix multiplication: a (m x n) * b (n x p) -> result (m x p).

  ## Examples

  iex> ElixirAiCore.Tensor.matmul([[1, 2]], [[3], [4]])
  [[11]]
  """
  def matmul(a, b) do
    b_t = transpose(b)

    for row <- a do
      for col <- b_t do
        dot(row, col)
      end
    end
  end

  @doc """
  Transpose a matrix (list of lists).

  ## Examples

  iex> ElixirAiCore.Tensor.transpose([[1, 2, 3], [4, 5, 6]])
  [[1, 4], [2, 5], [3, 6]]
  """
  def transpose(matrix) do
    matrix
    |> Enum.zip()
    |> Enum.map(&Tuple.to_list/1)
  end

  @doc """
  Apply a function element-wise on a tensor (recursively).

  ## Examples

  iex> ElixirAiCore.Tensor.map([[1, -2], [3, -4]], &max(&1, 0))
  [[1, 0], [3, 0]]
  """
  def map(tensor, fun) when is_list(tensor), do: Enum.map(tensor, &map(&1, fun))
  def map(value, fun), do: fun.(value)

  @doc """
  Add a bias vector to each row of a matrix (broadcasting).

  ## Examples

  iex> ElixirAiCore.Tensor.add_bias([[1, 2], [3, 4]], [0.1, 0.2])
  [[1.1, 2.2], [3.1, 4.2]]
  """
  def add_bias(matrix, bias_vector) do
    Enum.map(matrix, fn row ->
      Enum.zip(row, bias_vector)
      |> Enum.map(fn {x, b} -> x + b end)
    end)
  end

  @doc """
  ReLU activation function applied element-wise.

  ## Examples

  iex> ElixirAiCore.Tensor.relu([[1, -2], [3, -4]])
  [[1, 0], [3, 0]]
  """
  def relu(tensor), do: map(tensor, &max(&1, 0))

  @doc """
  Softmax function applied to a vector, converting logits to probabilities.

  ## Examples

  iex> ElixirAiCore.Tensor.softmax([1.0, 2.0, 3.0])
  [0.09003057, 0.24472847, 0.66524096]
  """
  def softmax(vector) when is_list(vector) do
    exps = Enum.map(vector, &:math.exp(&1))
    sum_exps = Enum.sum(exps)
    Enum.map(exps, &(&1 / sum_exps))
  end
end
