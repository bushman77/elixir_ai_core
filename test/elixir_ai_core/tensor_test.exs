# test/elixir_ai_core/tensor_test.exs
defmodule ElixirAiCore.TensorTest do
  use ExUnit.Case, async: true
  alias ElixirAiCore.Tensor

  test "dot product of vectors" do
    assert Tensor.dot([1, 2, 3], [4, 5, 6]) == 32
  end

  test "matrix multiplication" do
    a = [[1, 2], [3, 4]]
    b = [[5, 6], [7, 8]]
    expected = [[19, 22], [43, 50]]
    assert Tensor.matmul(a, b) == expected
  end

  test "transpose matrix" do
    matrix = [[1, 2, 3], [4, 5, 6]]
    expected = [[1, 4], [2, 5], [3, 6]]
    assert Tensor.transpose(matrix) == expected
  end

  test "element-wise map" do
    tensor = [[1, -2], [3, -4]]
    expected = [[1, 0], [3, 0]]
    assert Tensor.map(tensor, &max(&1, 0)) == expected
  end

  test "bias addition with broadcasting" do
    matrix = [[1, 2], [3, 4]]
    bias = [0.1, 0.2]
    expected = [[1.1, 2.2], [3.1, 4.2]]
    assert Tensor.add_bias(matrix, bias) == expected
  end

  test "relu activation" do
    tensor = [[1, -2], [3, -4]]
    expected = [[1, 0], [3, 0]]
    assert Tensor.relu(tensor) == expected
  end

  test "softmax activation" do
    logits = [1.0, 2.0, 3.0]
    result = Tensor.softmax(logits)
    # Softmax values sum to 1 and highest probability corresponds to highest input
    assert_in_delta Enum.sum(result), 1.0, 1.0e-6
    assert Enum.at(result, 2) > Enum.at(result, 1)
    assert Enum.at(result, 1) > Enum.at(result, 0)
  end
end
