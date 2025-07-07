defmodule ElixirAiCore.BrainTrainerTest do
  use ExUnit.Case, async: false

  alias ElixirAiCore.BrainTrainer
  alias Brain
  alias BrainCell
  alias BrainOutput

  @phrase ["hey", "buddy", "how", "are", "you"]

  setup do
    Registry.start_link(keys: :unique, name: BrainCell.Registry)
    # Ensure clean DETS table
    :ok
  end

  test "teaches and recalls a simple sentence chain" do
    # Step 1: Teach the chain
    assert :ok = BrainTrainer.teach_chain(@phrase)
    # Step 2: Confirm connection wiring
    first = BrainCell.state("hey")
    assert [%{target_id: "buddy"}] = first.connections

    # Step 3: Fire and wait for signal to propagate
    assert :ok = BrainCell.fire("hey", 1.0)
    Process.sleep(300)

    # Step 4: Output should follow the entire chain
    output = BrainOutput.top_words("hey")
    assert output == "hey buddy how are you"
  end
end
