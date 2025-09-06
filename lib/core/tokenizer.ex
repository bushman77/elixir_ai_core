defmodule Core.Tokenizer do
  @moduledoc """
  Tokenizer that:
    • canonicalizes + normalizes input
    • greedily merges known multiword phrases (longest match first)
    • emits %Core.Token{} structs (POS starts empty; filled later by POS engine)

  Accepts either a raw sentence (binary) or a %Core.SemanticInput{}.
  """

  require Logger
  alias Core.{Token, SemanticInput}
  alias Core.{MultiwordMatcher, Contractions}

  # ── Public API ────────────────────────────────────────────────────────────────

  @doc "Tokenizes a %SemanticInput{} in place (no side effects)."
  @spec tokenize(SemanticInput.t()) :: SemanticInput.t()
  def tokenize(%SemanticInput{sentence: s} = input) when is_binary(s) do
    s1   = canonicalize_sentence(s)
    norm = normalize_text(s1)

    {tokens, token_structs} = do_tokenize(norm, input.source || :user)

    %SemanticInput{
      input
      | original_sentence: input.original_sentence || s,
        sentence: norm,
        tokens: tokens,
        token_structs: token_structs
    }
  end

  @doc "Tokenizes a raw sentence and returns a fresh %Core.SemanticInput{}."
  @spec tokenize(binary()) :: SemanticInput.t()
  def tokenize(sentence) when is_binary(sentence) do
    s1   = canonicalize_sentence(sentence)
    norm = normalize_text(s1)

    {tokens, token_structs} = do_tokenize(norm, :user)

    %SemanticInput{
      original_sentence: sentence,
      sentence: norm,
      source: :user,
      tokens: tokens,
      token_structs: token_structs
    }
  end

  # ── Internal ─────────────────────────────────────────────────────────────────

# keep ONE version of this function in the file
@spec do_tokenize(binary(), atom()) :: {[String.t()], [Token.t()]}
defp do_tokenize(sentence, source) when is_binary(sentence) do
  # handle empty/whitespace input without using a guard
  if String.trim(sentence) == "" do
    {[], []}
  else
    words =
      sentence
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&Contractions.canonicalize/1)

    merged = Core.MultiwordMatcher.merge_words(words)

    token_structs =
      merged
      |> Enum.with_index()
      |> Enum.map(fn {phrase, index} ->
        %Core.Token{
          phrase: phrase,
          text: phrase,
          position: index,
          source: source,
          # tag functional phrases immediately; others stay [] for POSEngine
          pos: Core.MultiwordMatcher.pos_override(phrase)
        }
      end)

    {Enum.map(token_structs, & &1.phrase), token_structs}
  end
end

  # ── Normalization ────────────────────────────────────────────────────────────

  @doc false
  @spec canonicalize_sentence(binary()) :: binary()
  defp canonicalize_sentence(s) do
    cond do
      function_exported?(Contractions, :canonicalize_sentence, 1) ->
        Contractions.canonicalize_sentence(s)

      function_exported?(Contractions, :normalize, 1) ->
        Contractions.normalize(s)

      true ->
        s
    end
  end

  @doc false
  @spec normalize_text(binary()) :: binary()
  defp normalize_text(s) do
    s
    |> :unicode.characters_to_nfc_binary()
    |> String.downcase()
    |> strip_control()
    |> collapse_ws()
    |> keep_word_internals()
    |> strip_outer_punct()
    |> collapse_ws()
    |> String.trim()
  end

  @doc false
  @spec strip_control(binary()) :: binary()
  defp strip_control(s), do: String.replace(s, ~r/[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}]/u, "")

  @doc false
  @spec collapse_ws(binary()) :: binary()
  defp collapse_ws(s), do: String.replace(s, ~r/\s+/u, " ")

  @doc false
  @spec keep_word_internals(binary()) :: binary()
  defp keep_word_internals(s) do
    s
    # drop hyphens/apostrophes only when *not* surrounded by letters/numbers
    |> String.replace(~r/(?<![\p{L}\p{N}])['-]|['-](?![\p{L}\p{N}])/u, "")
    # keep decimal points in numbers; drop stray dots
    |> String.replace(~r/(?<!\p{N})\.(?!\p{N})/u, "")
  end

  @doc false
  @spec strip_outer_punct(binary()) :: binary()
  defp strip_outer_punct(s), do: String.replace(s, ~r/[^\p{L}\p{N}\s'\-\.]/u, "")
end

