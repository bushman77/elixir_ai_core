defmodule ElixirAiCore.ModelServerTest do
  use ExUnit.Case, async: true

  alias ElixirAiCore.ModelServer
  alias ElixirAiCore.Core

  setup do
    {:ok, pid} = ModelServer.start_link([])
    %{pid: pid}
  end

  test "load_model sets model in state", %{pid: _pid} do
    assert :ok == ModelServer.load_model(%{name: "test_model"})
  end

  test "infer returns error if no model loaded", %{pid: _pid} do
    assert {:error, :no_model_loaded} == ModelServer.infer(%{input: "input"})
  end

  test "inference returns model output when model is loaded", %{pid: _pid} do
    assert :ok == ModelServer.load_model(&Core.dummy_model/1)

    assert {:ok, :greeting} == ModelServer.infer(%{input: "Hello"})
    assert {:ok, :unknown} == ModelServer.infer(%{input: "???!!!"})
  end
end
