defmodule BrainContractTest do
  use ExUnit.Case, async: false

  # Make sure the Brain process is running for these tests
  setup do
    case Process.whereis(Brain) do
      nil -> {:ok, _pid} = Brain.start_link(nil)
      _pid -> :ok
    end
    :ok
  end

  test "Brain exposes get/1 and returns nil for unknown or unsupported inputs" do
    assert function_exported?(Brain, :get, 1)

    # Unknown string (allowed contract today: may be nil)
    assert is_nil(Brain.get("__surely_unseen__#{System.unique_integer([:positive])}"))

    # Unsupported type hits the fallback clause and must be nil (no DB touch)
    assert is_nil(Brain.get(:not_a_supported_type))
  end

  test "snapshot returns expected keys and types (no DB required)" do
    snap = Brain.snapshot()
    assert is_map(snap)
    assert Map.has_key?(snap, :attention)
    assert Map.has_key?(snap, :activation_log)
    assert Map.has_key?(snap, :active_cells)
    assert is_map(snap.active_cells)
    assert is_list(snap.activation_log)
  end

  test "LLM ctx set/get/clear roundtrips cleanly" do
    ctx = Enum.map(1..5, &"token-#{&1}")
    Brain.set_llm_ctx(ctx, "gpt-local")
    # cast is async; give it a tick
    Process.sleep(10)

    %{ctx: got_ctx, model: model} = Brain.get_llm_ctx()
    assert got_ctx == ctx
    assert model == "gpt-local"

    Brain.clear_llm_ctx()
    Process.sleep(10)
    %{ctx: got_ctx2, model: model2} = Brain.get_llm_ctx()
    assert is_nil(got_ctx2)
    assert is_nil(model2)
  end

  test "register_activation logs an event even without DB" do
    before = Brain.snapshot().activation_log
    Brain.register_activation("unit_test_cell_id")
    Process.sleep(10) # cast -> handle_cast

    after_log = Brain.snapshot().activation_log
    assert length(after_log) >= length(before)
    assert Enum.any?(after_log, &match?(%{id: "unit_test_cell_id", at: _}, &1))
  end

  test "prune_by_intent_pos is pipe-friendly and returns input unchanged" do
    sem = %{intent: :greet, foo: :bar}
    assert Brain.prune_by_intent_pos(sem) == sem
    # Should also not crash if intent missing
    sem2 = %{foo: :bar}
    assert Brain.prune_by_intent_pos(sem2) == sem2
  end
end

