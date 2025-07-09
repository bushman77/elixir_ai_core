defmodule Core.DBTest do
  use ExUnit.Case
  alias Core.DB
  alias BrainCell

  setup do
    start_supervised!(DB)

    # Insert a test brain cell
    cell = %BrainCell{id: "test|noun|1", word: "test", pos: :noun}
    DB.put(cell)

    # Add a second for word-matching
    DB.put(%BrainCell{id: "test|verb|1", word: "test", pos: :verb})

    :ok
  end

  test "get/2 returns a cell by id" do
    assert {:ok, %BrainCell{id: "test|noun|1"}} = DB.get("test|noun|1", :id)
  end

  test "get/2 returns list of cells by word" do
    result = DB.get("test", :word)
    assert is_list(result)
    assert Enum.count(result) == 2
    assert Enum.all?(result, fn c -> c.word == "test" end)
  end

  test "get/1 defaults to word mode" do
    result = DB.get("test")
    assert is_list(result)
  end
end
