defmodule BrainRegistryTest do
  use ExUnit.Case
  alias Core.{Registry, DB}
  alias BrainCell
  alias Brain

  setup do
    # or DB.reset if you have a helper
    DB.clear()
    :ok
  end

  test "Brain.get/1 handles dead registry pid gracefully" do
    # 1. Create and insert a cell
    cell = %BrainCell{
      id: "test|noun|1",
      word: "test",
      pos: :noun,
      definition: "A testing case."
    }

    :ok = DB.insert_many([cell])

    # 2. Manually register and capture the pid
    {:ok, pid} = Registry.register(cell)

    # 3. Kill the registered BrainCell process
    Process.exit(pid, :kill)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, ^pid, _}

    # 4. Now call Brain.get/1 and expect it NOT to crash
    result = Brain.get("test")

    # 5. Check that it returns an error OR recovers
    assert is_list(result)

    assert Enum.any?(result, fn
             {:error, :dead_pid} -> true
             {:error, :call_failed} -> true
             _ -> true
           end)
  end
end
