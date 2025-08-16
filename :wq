#Mix.install([
#  {:nx, "~> 0.9"},
#  {:axon, "~> 0.7"}
#])

alias FRP.{Features, Labels}
alias FRP.Train

# 1) Collect a tiny seed set from canned examples (replace with your logs)
examples = [
  %{sentence: "how do i install vim-elixir on vim", intent: :how_to, confidence: 0.6},
  %{sentence: "fix this compile error: defp undefined", intent: :troubleshoot, confidence: 0.7},
  %{sentence: "thanks!", intent: :thanks, confidence: 0.9},
  %{sentence: "fuck you", intent: :insult, confidence: 1.0},
  %{sentence: "can you show me step by step", intent: :how_to, confidence: 0.5},
  %{sentence: "it still fails after step 2", intent: :troubleshoot, confidence: 0.6}
]

samples =
  for sem <- examples do
    {x, _} = Features.build(sem)
    lab = Labels.from_semantic(sem)
    %{x: Nx.to_flat_list(x), reg: lab.reg, cls: lab.cls}
  end

train = Train.to_batches(samples, 4)
val   = Train.to_batches(samples, 4)

{_model, state} = Train.train(train, val, 12, 1.0e-3)

# Persist params for runtime
params = state.model_state
File.write!("priv/frp_params.nx", :erlang.term_to_binary(params))
IO.puts("Saved FRP params to priv/frp_params.nx")

