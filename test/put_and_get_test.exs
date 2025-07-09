defmodule Core.DBTest do
  use ExUnit.Case, async: false

  alias Core.DB
  alias BrainCell

  setup do
    pid =
      try do
        start_supervised!(Core.DB)
      rescue
        _ ->
          # Assume already started, find pid by name
          Process.whereis(Core.DB)
      end

    DB.clear()
    {:ok, pid: pid}
  end

  test "insert_many and get by word returns all BrainCell structs" do
    word = "testword"

    cells = [
      %BrainCell{id: "#{word}|noun|1", word: word, pos: :noun, definition: "def1"},
      %BrainCell{id: "#{word}|verb|2", word: word, pos: :verb, definition: "def2"},
      %BrainCell{id: "#{word}|adj|3", word: word, pos: :adjective, definition: "def3"}
    ]

    # Insert all cells
    DB.insert_many(cells)

    # Retrieve by word
    retrieved = DB.get(word, :word)

    # Assert all inserted cells are retrieved
    assert Enum.count(retrieved) == length(cells)

    # Assert each retrieved item is a BrainCell struct with matching id and pos
    for cell <- cells do
      assert Enum.any?(retrieved, fn r ->
               r.__struct__ == BrainCell and r.id == cell.id and r.pos == cell.pos
             end)
    end
  end

  test "get by id returns correct BrainCell struct" do
    cell = %BrainCell{id: "unique_id_1", word: "unique", pos: :noun, definition: "def"}
    DB.put(cell)

    {:ok, retrieved} = DB.get(cell.id, :id)

    assert retrieved.__struct__ == BrainCell
    assert retrieved.id == cell.id
    assert retrieved.pos == cell.pos
  end
end
