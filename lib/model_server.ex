defmodule ModelServer do
  @moduledoc """
  GenServer managing AI model lifecycle and inference.
  """

  use GenServer
  alias ElixirAiCore.Core

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def load_model(model_data) do
    GenServer.call(__MODULE__, {:load_model, model_data})
  end

  def infer(input) do
    GenServer.call(__MODULE__, {:infer, input})
  end

  def init(state) do
    {:ok, Map.put(state, :model, nil)}
  end

  def handle_call({:load_model, model_data}, _from, state) do
    {:reply, :ok, Map.put(state, :model, model_data)}
  end


def handle_call({:infer, input}, _from, %{model: nil} = state) do
  {:reply, {:error, :no_model_loaded}, state}
end

def handle_call({:infer, input}, _from, %{model: {_, _} = model} = state) do
  try do
    output = Core.infer(model, input)
    {:reply, {:ok, output}, state}
  rescue
    e -> {:reply, {:error, e}, state}
  end
end

  def handle_call({:infer, _input}, _from, %{model: nil} = state) do
    {:reply, {:error, :no_model_loaded}, state}
  end

  def handle_call({:infer, input}, _from, state) do
    # Delegate inference logic to Core, passing current model (or nil)
    output = Core.infer(state.model, input)
    {:reply, output, state}
  end
end
