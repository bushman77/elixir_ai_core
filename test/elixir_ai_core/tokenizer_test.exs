defmodule ElixirAiCore.TokenizerTest do
    use ExUnit.Case, async: true
    alias ElixirAiCore.Tokenizer

    test "word_to_id is deterministic" do
          assert Tokenizer.word_to_id("abc") == Tokenizer.word_to_id("abc")
        end

    test "different words produce different ids" do
          refute Tokenizer.word_to_id("abc") == Tokenizer.word_to_id("bac")
        end

    test "embed returns a float between 0 and 1" do
          embedded = Tokenizer.embed("test")
          assert is_float(embedded)
          assert embedded >= 0.0 and embedded <= 1.0
        end
end

