defmodule ElixirAiCore.ModelServerTest do
    use ExUnit.Case, async: true
    alias ElixirAiCore.ModelServer

    setup do
          {:ok, pid} = ModelServer.start_link([])
          %{pid: pid}
        end

    test "load_model sets model in state", %{pid: pid} do
          assert :ok == ModelServer.load_model(%{name: "test_model"})
        end

    test "infer returns error if no model loaded", %{pid: pid} do
          assert {:error, :no_model_loaded} == ModelServer.infer("input")
        end
end

