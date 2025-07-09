defmodule BrainCellRegistryTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, _} = Registry.start_link(keys: :unique, name: :test_braincell_registry)
    :ok
  end

  defmodule DummyBrainCell do
    use GenServer

    def start_link(id) do
      GenServer.start_link(__MODULE__, id)
    end

    def init(id) do
      Registry.register(:test_braincell_registry, id, [])
      {:ok, %{id: id}}
    end
  end

  defp extract_word(id) do
    id
    |> String.split("|")
    |> List.first()
  end

  test "filter braincells by word extracting from id" do
    {:ok, _pid1} = DummyBrainCell.start_link("hello|noun|1")
    {:ok, _pid2} = DummyBrainCell.start_link("hello|verb|2")
    {:ok, _pid3} = DummyBrainCell.start_link("world|noun|1")
    {:ok, _pid4} = DummyBrainCell.start_link("poop|noun|1")

    # Wait for processes to register
    Process.sleep(50)

    all_entries =
      Registry.select(:test_braincell_registry, [
        {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
      ])

    extract_word = fn id ->
      id |> String.split("|") |> List.first()
    end

    # Filter for "hello"
    hello_entries =
      Enum.filter(all_entries, fn {id, _pid, _meta} ->
        extract_word.(id) == "hello"
      end)
      |> Enum.map(fn {id, _pid, _meta} -> id end)
      |> Enum.sort()

    assert hello_entries == ["hello|noun|1", "hello|verb|2"]

    # Filter for "poop"
    poop_entries =
      Enum.filter(all_entries, fn {id, _pid, _meta} ->
        extract_word.(id) == "poop"
      end)
      |> Enum.map(fn {id, _pid, _meta} -> id end)
      |> Enum.sort()

    assert poop_entries == ["poop|noun|1"]
  end
end
