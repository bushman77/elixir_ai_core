defmodule LexiconEnricherIntegrationTest do
  use ExUnit.Case, async: false

  alias LexiconEnricher

  @tag :integration
  test "enrich returns brain cells for a common English word" do
    word = "interesting"

    result = LexiconEnricher.enrich(word)
    IO.inspect(result)
    assert {:ok, cells} = result
    assert is_list(cells)

    assert Enum.all?(cells, fn cell ->
             %BrainCell{} = cell
             cell.word == word
             cell.definition != nil and cell.definition != ""
           end)
  end

  @tag :integration
  test "enrich returns error for a nonsense word" do
    word = "thisisnotawordxyz"

    assert {:error, :not_found} = LexiconEnricher.enrich(word)
  end
end
