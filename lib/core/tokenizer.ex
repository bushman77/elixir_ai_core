defmodule Core.Tokenizer do
  @moduledoc """
  Tokenizer that:
    • normalizes + decontracts input
    • greedily merges known multiword phrases (longest match first)
    • emits %Core.Token{} structs with position/source metadata

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
# at top of file

defp do_tokenize(sentence, source) when sentence in ["", " "], do: {[], []}
defp do_tokenize(sentence, source) do
  {us_split, words} =
    :timer.tc(fn ->
      sentence
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&Contractions.canonicalize/1)
    end)

  {us_merge, merged} = :timer.tc(fn -> Core.MultiwordMatcher.merge_words(words) end)

  token_structs =
    merged
    |> Enum.with_index()
    |> Enum.map(fn {phrase, index} ->
      %Token{
        phrase: phrase, text: phrase, position: index, source: source,
        pos: Core.MultiwordMatcher.pos_override(phrase)
      }
    end)

  Logger.debug("TOKENIZE split=#{div(us_split,1000)}ms merge=#{div(us_merge,1000)}ms in=#{inspect words} out=#{inspect merged}")
  {Enum.map(token_structs, & &1.phrase), token_structs}
end

  @spec do_tokenize(binary(), atom()) :: {[String.t()], [Token.t()]}
  defp do_tokenize(sentence, _source) when sentence in ["", " "], do: {[], []}

  defp do_tokenize(sentence, source) do
    words =
      sentence
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&Contractions.canonicalize/1) # e.g., "im" -> "i'm"

    merged = MultiwordMatcher.merge_words(words)

    token_structs =
      merged
      |> Enum.with_index()
      |> Enum.map(fn {phrase, index} ->
        %Token{
          phrase: phrase,
          text: phrase,
          position: index,
          source: source,
          # tag functional phrases immediately; others stay [] for POSEngine
          pos: MultiwordMatcher.pos_override(phrase)
        }
      end)

    {Enum.map(token_structs, & &1.phrase), token_structs}
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
    |> String.replace(~r/(?<![\p{L}\p{N}])['-]|['-](?![\p{L}\p{N}])/u, "")
    |> String.replace(~r/(?<!\p{N})\.(?!\p{N})/u, "")
  end

  @doc false
  @spec strip_outer_punct(binary()) :: binary()
  defp strip_outer_punct(s), do: String.replace(s, ~r/[^\p{L}\p{N}\s'\-\.]/u, "")
end

