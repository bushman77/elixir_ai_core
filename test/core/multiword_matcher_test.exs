defmodule Core.MultiwordMatcherTest do
  use ExUnit.Case, async: true
  alias Core.{MultiwordMatcher, SemanticInput}

  test "does not hang on single-word MWE followed by extra token" do
    sem = %SemanticInput{sentence: "hello there", original_sentence: "hello there", source: :user}
    # Tokenizer may call MultiwordMatcher internally; if not, call explicitly:
    tokens = [%Core.Token{text: "hello"}, %Core.Token{text: "there"}]
    merged = MultiwordMatcher.merge_words(tokens)
    assert is_list(merged) and length(merged) == 2
  end
end

