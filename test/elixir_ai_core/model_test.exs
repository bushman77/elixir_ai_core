defmodule ElixirAiCore.ModelTest do
  use ExUnit.Case, async: true

  alias ElixirAiCore.Model

  @default_layers [2, 3, 1]
  @default_weights [[0.5, -0.2], [0.3, 0.8], [1.0]]
  @default_biases [[0.1, 0.2], [0.0, -0.1], [0.5]]

  setup do
    model = %Model{
      name: "test_model",
      layers: @default_layers,
      weights: @default_weights,
      biases: @default_biases
    }

    {:ok, model: model}
  end

  test "sanity check model struct is valid", %{model: model} do
    assert model.name == "test_model"
    assert length(model.layers) == 3
    assert Enum.all?(model.weights, &is_list/1)
  end
end
