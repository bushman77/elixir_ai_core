defmodule Brain.AttentionTest do
  use ExUnit.Case, async: true
  alias Brain.Attention

  describe "scaled_dot_product/3" do
    test "computes attention for a simple Q, K, V set" do
      q = Nx.tensor([[1.0, 0.0]])
      k = Nx.tensor([[1.0, 0.0], [0.0, 1.0]])
      v = Nx.tensor([[10.0, 0.0], [0.0, 5.0]])

      result = Attention.scaled_dot_product(q, k, v)

      # Expect the output to attend more to the first vector
      expected = Nx.tensor([[10.0, 0.0]])

      assert Nx.all_close(result, expected, atol: 1.0e-4)
    end
  end

  describe "scaled_dot_product/3 with multi-token Q" do
    test "computes attention over a sequence of queries" do
      # 3 queries (sequence length 3), each of dim 2
      q =
        Nx.tensor([
          [1.0, 0.0],
          [0.0, 1.0],
          [1.0, 1.0]
        ])

      # 2 keys (memory bank)
      k =
        Nx.tensor([
          [1.0, 0.0],
          [0.0, 1.0]
        ])

      # Corresponding values for those keys
      v =
        Nx.tensor([
          [10.0, 0.0],
          [0.0, 5.0]
        ])

      result = Brain.Attention.scaled_dot_product(q, k, v)

      # Let's manually compute expected values
      # Query 1 aligns with key 1 → mostly [10.0, 0.0]
      # Query 2 aligns with key 2 → mostly [0.0, 5.0]
      # Query 3 aligns with both equally → ~average of both: [5.0, 2.5]
      expected =
        Nx.tensor([
          [10.0, 0.0],
          [0.0, 5.0],
          [5.0, 2.5]
        ])

      assert Nx.all_close(result, expected, atol: 1.0e-4)
    end
  end

  describe "dopamine modulation of attention weights" do
    test "increased dopamine sharpens the softmax distribution" do
      q = Nx.tensor([[1.0, 0.0]])
      k = Nx.tensor([[1.0, 0.0], [0.0, 1.0]])
      v = Nx.tensor([[10.0, 0.0], [0.0, 5.0]])

      low_dop = Brain.Attention.debug_softmax(q, k, 0.5, 1.0)
      high_dop = Brain.Attention.debug_softmax(q, k, 2.0, 1.0)

      low_weights = low_dop[:weights]
      high_weights = high_dop[:weights]

      low_diff =
        low_weights
        |> Nx.reduce_max(axes: [1])
        |> Nx.subtract(Nx.reduce_min(low_weights, axes: [1]))
        |> Nx.to_flat_list()
        |> hd()

      high_diff =
        high_weights
        |> Nx.reduce_max(axes: [1])
        |> Nx.subtract(Nx.reduce_min(high_weights, axes: [1]))
        |> Nx.to_flat_list()
        |> hd()

      assert high_diff > low_diff
    end

    test "increased serotonin flattens attention distribution" do
      q = Nx.tensor([[1.0, 0.0]])
      k = Nx.tensor([[1.0, 0.0], [0.0, 1.0]])
      v = Nx.tensor([[10.0, 0.0], [0.0, 5.0]])

      low_ser = Brain.Attention.debug_softmax(q, k, 1.0, 0.5, 1.0)
      high_ser = Brain.Attention.debug_softmax(q, k, 1.0, 2.0, 1.0)

      low_weights = low_ser[:weights]
      high_weights = high_ser[:weights]

      low_diff =
        low_weights
        |> Nx.reduce_max(axes: [1])
        |> Nx.subtract(Nx.reduce_min(low_weights, axes: [1]))
        |> Nx.to_flat_list()
        |> hd()

      high_diff =
        high_weights
        |> Nx.reduce_max(axes: [1])
        |> Nx.subtract(Nx.reduce_min(high_weights, axes: [1]))
        |> Nx.to_flat_list()
        |> hd()

      assert high_diff > low_diff
    end
  end
end
