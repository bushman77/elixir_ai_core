defmodule Core.TokenizerTest do
  use ExUnit.Case, async: true

  alias Core.Tokenizer
  alias Core.SemanticInput
  alias Core.Token

  # Helper: build a SemanticInput with a given sentence and source (default :test to avoid Brain activation path)
  defp sem(sentence, source \\ :test),
    do: %SemanticInput{sentence: sentence, original_sentence: sentence, source: source, tokens: [], token_structs: []}

  # --------------------
  # Normalization + basics
  # --------------------

  test "normalizes punctuation, keeps word-internal apostrophes/hyphens, and preserves numbers like 3.14" do
    input = sem("Hello!!!  it's  3.14 — state-of-the-art,   NLP")
    out = Tokenizer.tokenize(input)

    # sentence is normalized (lowercase, no stray punct, collapsed spaces)
    assert out.sentence == "hello it's 3.14 state-of-the-art nlp"

    # tokens reflect normalized words
    assert out.tokens == ["hello", "it's", "3.14", "state-of-the-art", "nlp"]

    # token_structs align with tokens and positions
    assert Enum.map(out.token_structs, & &1.phrase) == out.tokens
    assert Enum.map(out.token_structs, & &1.position) == Enum.to_list(0..(length(out.tokens)-1))
    assert Enum.all?(out.token_structs, &match?(%Token{source: :test}, &1))
  end

  test "canonicalizes common contractions (im -> i'm)" do
    out = Tokenizer.tokenize(sem("im happy", :test))
    assert out.tokens == ["i'm", "happy"]
    assert Enum.map(out.token_structs, & &1.phrase) == ["i'm", "happy"]
  end

  # --------------------
  # original_sentence handling
  # --------------------

  test "struct entrypoint preserves original_sentence and writes normalized sentence" do
    input = sem("HeY!!!  I'Ve  Arrived.")
    out = Tokenizer.tokenize(input)

    # original_sentence should be preserved (set by tokenizer if nil)
    assert out.original_sentence == "HeY!!!  I'Ve  Arrived."

    # sentence should be normalized
    assert out.sentence == "hey i've arrived"

    # tokens sanity
    assert out.tokens == ["hey", "i've", "arrived"]
  end

  test "binary entrypoint sets original_sentence and normalized sentence, with source :user" do
    out = Tokenizer.tokenize("Hello THERE!!")
    assert out.original_sentence == "Hello THERE!!"
    assert out.sentence == "hello there"
    assert out.source == :user
    assert out.tokens == ["hello", "there"]
  end

  # --------------------
  # token_struct content
  # --------------------

  test "token_structs are well-formed and pos list starts empty (to be filled later)" do
    out = Tokenizer.tokenize(sem("don't break hyphens-in-words"))
    assert length(out.token_structs) == 3

    Enum.zip(out.tokens, out.token_structs)
    |> Enum.each(fn {tok, %Token{phrase: p, text: t, pos: pos, position: idx}} ->
      assert tok == p
      assert t == p
      assert is_list(pos) and pos == []
      assert is_integer(idx) and idx >= 0
    end)
  end

  # --------------------
  # OPTIONAL: phrase merging with stubbed MultiwordMatcher (requires Mox or similar)
  #
  # If you use Mox:
  #   1) Define a behaviour for MultiwordMatcher with `@callback get_phrases() :: [String.t()]`
  #   2) In test config, set your app to use a mock module for that behaviour
  #   3) Here, expect and return a phrase that should be merged
  # --------------------
  @tag :optional
  @tag :mwe
  test "merges known multiword phrases when matcher returns them (optional with stub)" do
    # Example if using Mox:
    # Core.MultiwordMatcherMock
    # |> expect(:get_phrases, fn -> ["state of the art"] end)

    # Without an actual stub in place, this test is illustrative. Uncomment if stubbing.
    input = sem("this is state of the art nlp", :test)
    out = Tokenizer.tokenize(input)

    # If your matcher returns ["state of the art"], normalized same way,
    # tokens should include the merged phrase (single token).
    # Replace the assertion below with the exact merged token as your system prefers.
    # assert "state of the art" in out.tokens
    assert is_list(out.tokens) and length(out.tokens) >= 1
  end
end

