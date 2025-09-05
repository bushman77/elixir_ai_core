defmodule ML.Adapters.LoRA do
  @moduledoc """
  Minimal LoRA-like delta applied to a Dense (projection) layer weights.
  We place it on the LM head to learn style (mood) without touching the base.
  """
  import Axon

  @doc """
  Wrap a logits tensor with an additive low-rank projection delta.
  Assumes the previous layer is the final hidden sequence H with shape {B,T,D}.
  We learn A (D x r) and B (r x V) and add alpha/r * H @ A @ B to logits.
  """
  def lora_logits(hidden, vocab_size, rank \\ 4, alpha \\ 8, tag \\ "grumpy") do
    {b, t, d} = Axon.Shape.shape(hidden)
    a = Axon.param("lora_A_#{tag}", fn _ -> Nx.random_normal({d, rank}) end)
    b_ = Axon.param("lora_B_#{tag}", fn _ -> Nx.random_normal({rank, vocab_size}) end)

    delta = Axon.nx(hidden, fn h, a, b ->
      Nx.dot(h, a) |> Nx.dot(b) |> Nx.multiply(alpha / rank)
    end, [a, b_])

    dense(hidden, vocab_size, name: :lm_head) |> add(delta)
  end
end
