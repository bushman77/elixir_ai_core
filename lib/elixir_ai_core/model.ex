defmodule ElixirAiCore.Model do
  @moduledoc """
  Core model definition. Agnostic, extendable, and built from scratch.
  """

  @type layer_size :: non_neg_integer()
  @type weight_matrix :: list(list(float()))
  @type bias_vector :: list(float())

  @type t :: %__MODULE__{
          name: String.t(),
          layers: [layer_size()],
          weights: [weight_matrix()],
          biases: [bias_vector()]
        }

  defstruct name: "unnamed_model",
            layers: [],
            weights: [],
            biases: []

  import Axon

  @doc """
  Builds a simple feedforward model with customizable input and output sizes.
  """
  def build(input_shape \\ {nil, 10}, output_shape \\ 1) do
    input("input", shape: input_shape)
    |> dense(32, activation: :relu)
    |> dense(32, activation: :relu)
    |> dense(output_shape, activation: :linear)
  end

  @doc """
  Prints the internal structure of the model.
  """
  def summary(model \\ build()) do
    IO.inspect(model, pretty: true)
  end

  @doc """
  Trains the model on the provided data.

  `data` should be an enumerable of `{input_batch, target_batch}` tuples.
  """
  def train(model, data, epochs \\ 10, learning_rate \\ 0.001) do
    [{inputs, _targets} | _] = data

    full_shape = Tuple.to_list(Nx.shape(inputs))

    feature_shape =
      case full_shape do
        [] -> [1]
        [_batch] -> [1]
        [_batch | rest] -> rest
      end

    final_shape = List.to_tuple([1 | feature_shape])
    params = Axon.build(model, final_shape)

    loss_fn = fn preds, targets -> Nx.mean(Nx.pow(preds - targets, 2)) end
    optimizer = Axon.Optimizers.adam(learning_rate)

    Enum.reduce(1..epochs, params, fn epoch, params_acc ->
      Enum.reduce(data, params_acc, fn {inputs, targets}, params_inner ->
        {loss, grad} =
          Nx.Defn.jit(fn params ->
            preds = Axon.predict(model, params, inputs)
            loss_fn.(preds, targets)
          end).(params_inner)

        IO.puts("Epoch #{epoch}, loss: #{Nx.to_number(loss)}")
        optimizer.(params_inner, grad)
      end)
    end)
  end
end
