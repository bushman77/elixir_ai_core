defmodule TokenizerTest do
  use ExUnit.Case
  alias Tokenizer
  alias Core.DB
  alias LexiconEnricher
  alias BrainCell

  describe "Tokenizer.tokenize/1" do
    setup do
      DB.clear()
      :ok
    end

    test "uses DB if word is already enriched" do
      DB.put(%BrainCell{id: "hello|noun|1", word: "hello", pos: :noun})

      result = Tokenizer.tokenize("hello")
      assert result == [%{word: "hello", pos: [:noun]}]
    end

    test "enriches missing word and re-uses from DB" do
      word = "greetings"
      # Confirm it's not yet in DB
      assert DB.get(word) == nil

      # Enrich manually like LexiconClient would do
      :ok = LexiconEnricher.enrich(word)

      result = Tokenizer.tokenize("greetings")
      assert [%{word: "greetings", pos: pos}] = result
      assert Enum.all?(pos, &is_atom/1)
    end

    test "returns [:unknown] if enrichment fails" do
      word = "blorptastic"

      result = Tokenizer.tokenize("blorptastic")
      assert result == [%{word: word, pos: [:unknown]}]
    end
  end
end
