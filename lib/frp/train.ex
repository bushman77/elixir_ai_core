defmodule FRP.Train do
  @moduledoc "Trainer utilities for FRP."
  import Axon
  alias Axon.Loop
  alias Nx, as: Nx
  alias FRP.Model

  @type loop_state :: %{
          model_state: term(),
          optimizer_state: term(),
          step_state: term(),
          hooks: term()
        }

  @doc """
  Train the FRP model.
  train_batches / val_batches streams yield:
    { %{"x" => x}, %{"reg" => reg_targets, "cls" => cls_indices} }
  """
  def train(train_batches, val_batches, epochs \\ 5, lr \\ 1.0e-3) do
    model = Model.spec()
    optimizer = Axon.Optimizers.adamw(lr: lr, weight_decay: 1.0e-4)

    loop =
      model
      |> Loop.trainer(&Model.loss/2, optimizer)
      |> Loop.metric(:reg_mse, &Axon.Metrics.mean_squared_error/2)
      |> Loop.metric(:cls_acc, &Axon.Metrics.accuracy/2)

    state = Loop.run(loop, train_batches, %{}, epochs: epochs, validation_data: val_batches)
    {model, state}
  end

  @doc """
  Make a simple batch stream from a list of samples:
    [%{x: [..128..], reg: [7], cls: int}, ...]
  """
  def to_batches(samples, batch \\ 64) do
    samples
    |> Enum.chunk_every(batch)
    |> Stream.map(fn chunk ->
      x   = chunk |> Enum.map(& &1.x)   |> Nx.tensor(type: {:f, 32})
      reg = chunk |> Enum.map(& &1.reg) |> Nx.tensor(type: {:f, 32})
      cls = chunk |> Enum.map(& &1.cls) |> Nx.tensor(type: {:s, 64})
      {%{"x" => x}, %{"reg" => reg, "cls" => cls}}
    end)
  end
end

