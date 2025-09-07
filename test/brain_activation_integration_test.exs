# test/brain_activation_integration_test.exs
defmodule BrainActivationIntegrationTest do
  use ExUnit.Case, async: false

  alias Core.Token
  alias BrainCell

  setup do
    # Ensure Brain is running
    case Process.whereis(Brain) do
      nil -> {:ok, _} = Brain.start_link(nil)
      _ -> :ok
    end

    # Keep enrichment off so we only use rows we insert/ensure
    Application.put_env(:elixir_ai_core, :enrichment_enabled, false)
    :ok
  end

  defp ensure_cells(word, pos_with_idx) do
    for {pos, idx} <- pos_with_idx do
      Brain.ensure_braincell(word, pos, sense_index: idx)
    end
  end

  test "get_or_start/1 starts processes for DB-backed braincells" do
    cells = ensure_cells("hello", [{"interjection", 1}, {"noun", 1}])

    # Before starting, nothing should be in the Registry
    Enum.each(cells, fn %BrainCell{id: id} ->
      assert Registry.lookup(Core.Registry, id) == []
    end)

    assert {:ok, []} = Brain.get_or_start("hello")
    Process.sleep(20)

    # After starting, each cell id should resolve to a live pid
    for %BrainCell{id: id} <- Brain.get_all("hello") do
      assert [{pid, _}] = Registry.lookup(Core.Registry, id)
      assert Process.alive?(pid)
    end
  end

test "attention/1 returns cells and logs activation (processes started via get_or_start)" do
  # Build multiple POS + sense variants for "run"
  _ = Brain.ensure_braincell("run", "verb",  sense_index: 1)
  _ = Brain.ensure_braincell("run", "verb",  sense_index: 2)
  _ = Brain.ensure_braincell("run", "noun",  sense_index: 1)

  # 1) Start processes for DB-backed cells (this is what actually spins them up)
  assert {:ok, []} = Brain.get_or_start("run")
  Process.sleep(20)

  # Confirm processes are registered and alive
  for %BrainCell{id: id} <- Brain.get_all("run") do
    assert [{pid, _}] = Registry.lookup(Core.Registry, id)
    assert Process.alive?(pid)
  end

  # 2) Now exercise attention: returns cells + logs activation (but doesn't start them)
  cells = Brain.attention([%Core.Token{phrase: "run"}])
  assert length(cells) >= 2
  Process.sleep(30)

  # Activation log should contain our specific IDs (since IDs were present)
  log = Brain.snapshot().activation_log
  assert Enum.any?(log, fn %{id: id} -> is_binary(id) and String.starts_with?(id, "run|") end)
end

  test "link_cells/1 attaches BrainCell structs to SemanticInput" do
    _ = Brain.ensure_braincell("apple", "noun", sense_index: 1)

    si = %Core.SemanticInput{token_structs: [%Token{phrase: "apple"}]}
    si2 = Brain.link_cells(si)

    assert match?([%BrainCell{} | _], si2.cells)
  end

test "get_cells/1 lists active ids for a word" do
  _ = Brain.ensure_braincell("alpha", "noun", sense_index: 1)
  _ = Brain.ensure_braincell("alpha", "verb", sense_index: 1)
  assert {:ok, []} = Brain.get_or_start("alpha")
  Process.sleep(20)

  ids = Brain.get_cells(%Core.Token{phrase: "alpha"})
  assert length(ids) >= 2
  assert Enum.all?(ids, &String.starts_with?(&1, "alpha|"))
end



test "activation_log is capped" do
  cap = 100   # matches @activation_log_max
  for i <- 1..(cap + 10), do: Brain.register_activation("cap-#{i}")
  Process.sleep(20)
  log = Brain.snapshot().activation_log
  assert length(log) == cap
end

test "ensure_braincell assigns increasing sense indices" do
  c1 = Brain.ensure_braincell("beta", "noun", sense_index: 1)
  c2 = Brain.ensure_braincell("beta", "noun") # auto-index next
  assert c1.id =~ ~r/^beta\|noun\|1$/
  assert c2.id =~ ~r/^beta\|noun\|\d+$/
  refute c1.id == c2.id
end

test "link_cells/1 attaches all cells for a word" do
  _ = Brain.ensure_braincell("gamma", "noun", sense_index: 1)
  _ = Brain.ensure_braincell("gamma", "verb", sense_index: 1)
  si  = %Core.SemanticInput{token_structs: [%Core.Token{phrase: "gamma"}]}
  si2 = Brain.link_cells(si)
  assert Enum.any?(si2.cells, & &1.pos == "noun")
  assert Enum.any?(si2.cells, & &1.pos == "verb")
end

test "cell_started populates active_cells" do
  pid = spawn(fn -> receive do _ -> :ok end end)
  send(Brain, {:cell_started, {"hello|noun|1", pid}})
  Process.sleep(10)
  assert Brain.snapshot().active_cells["hello|noun|1"] == pid
end

test "prune_by_intent_pos sends :attenuate to non-top POS cells" do
  # two fake cells
  noun = spawn(fn -> assert_receive {:attenuate, _}, 200 end)
  intj = spawn(fn -> refute_receive {:attenuate, _}, 200 end)
  send(Brain, {:cell_started, {"hi|noun|1", noun}})
  send(Brain, {:cell_started, {"hi|interjection|1", intj}})
  Process.sleep(10)

  Brain.prune_by_intent_pos(%{intent: :greet})
  Process.sleep(50)
end

test "after_attention strengthens connections in DB" do
  a = Brain.ensure_braincell("alpha", "noun", sense_index: 1)
  b = Brain.ensure_braincell("beta",  "noun", sense_index: 1)

  # ensure alpha has no edge to beta
  Core.DB.get!(BrainCell, a.id)
  |> BrainCell.changeset(%{connections: []})
  |> Core.DB.update!()

  send(Brain, {:after_attention, ["alpha", "beta"]})
  Process.sleep(30)

  a2 = Core.DB.get!(BrainCell, a.id)
  assert Enum.any?(a2.connections, &(&1["to"] == b.id and &1["strength"] >= 0.1))
end

test "after_attention is skipped when Brain mailbox is busy" do
  a = Brain.ensure_braincell("m1", "noun", sense_index: 1)
  b = Brain.ensure_braincell("m2", "noun", sense_index: 1)

  # Flood mailbox (>=200)
  for i <- 1..220, do: send(Brain, {:noise, i})
  send(Brain, {:after_attention, ["m1", "m2"]})
  Process.sleep(50)

  a2 = Core.DB.get!(BrainCell, a.id)
  refute Enum.any?(a2.connections, &(&1["to"] == b.id))
end

test "set_llm_ctx trims to llm_max (tail kept)" do
  long = Enum.map(1..9000, &"t#{&1}")
  Brain.set_llm_ctx(long, "gpt-local")
  Process.sleep(10)
  %{ctx: got, model: _} = Brain.get_llm_ctx()
  assert length(got) <= 8192
  assert hd(got) == Enum.at(long, length(long) - length(got))
end


end

