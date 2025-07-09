defmodule SemanticsTest do
  use ExUnit.Case
  alias Core

  @moduletag :semantics

  describe "Process user input" do
    test "basic structure works with known words" do
      input = "hello world"
      tokens = Tokenizer.tokenize(input)

      assert tokens == [%{pos: [:unknown], word: "hello"}, %{pos: [:unknown], word: "world"}]

      enriched =
        Enum.map(tokens, fn token ->
          token.pos
          |> case do
            [:unknown] ->
              {:ok, list} = LexiconEnricher.enrich(token.word)
              list

            _ ->
              []
          end
        end)

      assert length(enriched) == 2

      Enum.each(List.flatten(enriched), fn word ->
        Brain.put(word)
      end)

      assert true
    end
  end
end
