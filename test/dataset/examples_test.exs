defmodule ElixirAiCore.Dataset.ExamplesTest do
  use ExUnit.Case, async: true
  alias ElixirAiCore.Dataset.Examples
  alias ElixirAiCore.Dataset.Entry

  describe "Examples.minimal/0" do
    test "returns a list of Entry structs" do
      entries = Examples.minimal()

      assert is_list(entries)
      assert Enum.all?(entries, &match?(%Entry{}, &1))
    end

    test "each entry includes an input and label" do
      entries = Examples.minimal()

      Enum.each(entries, fn %Entry{input: input, label: label} ->
        assert input != nil
        assert label != nil
      end)
    end

    test "allows a variety of input types" do
      inputs = Examples.minimal() |> Enum.map(& &1.input)

      assert "Hello" in inputs
      assert %{species: "cat", has_tail: true} in inputs
      assert [:wake_up, :eat, :train] in inputs
    end
  end
end
