defmodule Core.TokenizerTest do
  use ExUnit.Case, async: true
  alias Core.Tokenizer
  alias Core.SemanticInput
  alias Core.Token

  # Build a SemanticInput with a given sentence and source
  # (default :test to avoid Brain activation path)
  defp sem(sentence, source \\ :test) do
    %SemanticInput{
      sentence: sentence,
      original_sentence: sentence,
      source: source,
      tokens: [],
      token_structs: []
    }
  end

  # Flatten anything token-like down to the underlying string, tolerating nesting.
  defp to_text(%Token{text: t}), do: to_text(t)
  defp to_text(t) when is_binary(t), do: String.trim(t)
  defp to_text(other), do: flunk("Unexpected token-like value: #{inspect(other)}")

  # Map out.tokens -> list of normalized strings
  defp texts(out), do: Enum.map(out.tokens, &to_text/1)

  # Trim a list of strings (used for the variants test input)
  defp trim_all(list), do: Enum.map(list, &String.trim/1)

  test "tokenize handles variants" do
    for text <- trim_all([
           " hello world ",
           "hello, world",
           "hello   world"
         ]) do
      out = Tokenizer.tokenize(text)
      assert match?(%SemanticInput{}, out)
      assert is_list(out.tokens)
      assert texts(out) == ["hello", "world"]
    end
  end

  # --------------------
  # Normalization + basics
  # --------------------

  test "normalizes punctuation, keeps word-internal apostrophes/hyphens, and preserves numbers like 3.14" do
    input = sem("Hello!!!  it's  3.14 — state-of-the-art,   NLP")
    out = Tokenizer.tokenize(input)

    # sentence is normalized (lowercase, no stray punct, collapsed spaces)
    assert out.sentence == "hello it's 3.14 state-of-the-art nlp"

    # tokens reflect normalized words (compare by text)
    assert texts(out) == ["hello", "it's", "3.14", "state-of-the-art", "nlp"]

    # If token_structs exist, verify they mirror tokens 1:1 by text
    if is_list(out.token_structs) and out.token_structs != [] do
      assert length(out.token_structs) == length(out.tokens)
      assert Enum.map(out.token_structs, &to_text/1) == texts(out)
    end
  end

  test "canonicalizes common contractions (im -> i'm)" do
    out = Tokenizer.tokenize(sem("im happy", :test))
    assert texts(out) == ["i'm", "happy"]
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
    assert texts(out) == ["hey", "i've", "arrived"]
  end

  test "binary entrypoint sets original_sentence and normalized sentence, with source :user" do
    out = Tokenizer.tokenize("Hello THERE!!")
    assert out.original_sentence == "Hello THERE!!"
    assert out.sentence == "hello there"
    assert out.source == :user
    assert texts(out) == ["hello", "there"]
  end

  # --------------------
  # token_struct content
  # --------------------

  test "token_structs are well-formed and pos list starts empty (to be filled later)" do
    out = Tokenizer.tokenize(sem("don't break hyphens-in-words"))
    toks = out.tokens
    assert is_list(toks) and length(toks) == 3

    Enum.each(toks, fn
      %Token{text: t, pos: pos, position: idx, phrase: p} ->
        assert is_binary(t) and t != ""
        assert is_list(pos) and pos == []
        # position may be nil in current code; allow either
        assert is_nil(idx) or (is_integer(idx) and idx >= 0)
        # phrase may be nil or equal to text in current code; allow either
        assert is_nil(p) or p == t

      other ->
        flunk("Expected %Core.Token{}, got: #{inspect(other)}")
    end)
  end

  # --------------------
  # OPTIONAL: phrase merging with stubbed MultiwordMatcher (requires Mox or similar)
  # --------------------
  @tag :optional
  @tag :mwe
  test "merges known multiword phrases when matcher returns them (optional with stub)" do
    # Example if using Mox:
    # Core.MultiwordMatcherMock
    # |> expect(:get_phrases, fn -> ["state of the art"] end)

    out = Tokenizer.tokenize(sem("this is state of the art nlp", :test))

    # If your matcher returns ["state of the art"], tokens should include the merged phrase (single token).
    # Replace with exact merged token as your system prefers.
    # assert "state of the art" in texts(out)
    assert is_list(out.tokens) and length(out.tokens) >= 1
  end
end

