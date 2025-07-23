Mix.Task.run("app.start")

require Axon
import Nx.Defn

model =
  Axon.input("x", shape: {nil, 1})
  |> Axon.dense(1)
  |> Axon.relu()

# Create parameter tensor template
params = Axon.init(model, %{"x" => Nx.template({1, 1}, :f32)})

# Dummy input tensor
input = Nx.tensor([[1.0], [2.0], [3.0]])

# Run a forward pass
output = Axon.predict(model, params, %{"x" => input})

IO.inspect(output, label: "Axon Hello World Output")

