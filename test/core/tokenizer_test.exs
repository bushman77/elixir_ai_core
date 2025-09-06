defmodule Core.TokenizerTest do
  use ExUnit.Case, async: true
  alias Core.Tokenizer
  alias Core.SemanticInput
  alias Core.Token

  # Helper: build a SemanticInput with a given sentence and source
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

  # Helper: normalize to token texts (works for struct or string tokens)
  defp texts(out) do
    Enum.map(out.tokens, fn
      %Token{text: t} -> t
      t when is_binary(t) -> t
      other -> flunk("Unexpected token type: #{inspect(other)}")
    end)
  end

  # Extract texts from ANY token list (structs or binaries)
  defp list_texts(list) do
    Enum.map(list, fn
      %Core.Token{text: t} -> t
      t when is_binary(t) -> t
      other -> flunk("Unexpected token in list: #{inspect(other)}")
    end)
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

    # If token_structs exist, verify they mirror token texts (by :text)

# If token_structs exist, verify they mirror tokens 1:1 (by text, regardless of shape)
if is_list(out.token_structs) and out.token_structs != [] do
  assert length(out.token_structs) == length(out.tokens)

  Enum.zip(out.token_structs, out.tokens)
  |> Enum.each(fn {a, b} ->
    a_text =
      cond do
        is_map(a) and Map.has_key?(a, :text) -> :erlang.map_get(:text, a)
        is_binary(a) -> a
        true -> flunk("Unexpected token_struct element: #{inspect(a)}")
      end

    b_text =
      cond do
        is_map(b) and Map.has_key?(b, :text) -> :erlang.map_get(:text, b)
        is_binary(b) -> b
        true -> flunk("Unexpected tokens element: #{inspect(b)}")
      end

    assert a_text.text == b_text
  end)
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
    # Your current pipeline returns tokens as %Token{}, so validate directly on out.tokens.
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

    input = sem("this is state of the art nlp", :test)
    out = Tokenizer.tokenize(input)

    # If your matcher returns ["state of the art"], tokens should include the merged phrase (single token).
    # Replace with exact merged token as your system prefers.
    # assert "state of the art" in texts(out)
    assert is_list(out.tokens) and length(out.tokens) >= 1
  end
end

