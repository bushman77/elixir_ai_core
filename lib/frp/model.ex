defmodule FRP.Model do
  @moduledoc """
  Tiny two-head MLP for fuzzy response planning.
  Outputs:
    - reg (7 sliders in 0..1)
    - logits (7-way bucket logits)
  """
  import Axon
  alias Nx, as: Nx

  @n_in FRP.Features.n_in()
  @n_reg 7
  @n_cls 7

  def spec() do
    x = input("x", shape: {nil, @n_in})

    base =
      x
      |> dense(128, activation: :gelu)
      |> dropout(0.1)
      |> dense(64, activation: :gelu)

    %{
      "reg" => base |> dense(@n_reg, activation: :sigmoid, name: "reg"),
      "logits" => base |> dense(@n_cls, name: "logits")
    }
  end

  def loss(y_true, y_pred) do
    reg_loss = Axon.Losses.mean_squared_error(y_true["reg"], y_pred["reg"])
    cls_loss = Axon.Losses.sparse_categorical_cross_entropy(
      y_true["cls"], y_pred["logits"], from_logits: true
    )
    0.6 * reg_loss + 0.4 * cls_loss
  end

  def metrics(), do: [reg_mse: &Axon.Metrics.mean_squared_error/2, cls_acc: &Axon.Metrics.accuracy/2]

  @doc "Pure predict. Accepts model params (state.model_state) and an x tensor."
  def predict(params, x_tensor) do
    model = spec()
    Axon.predict(model, params, %{"x" => x_tensor})
  end
end

