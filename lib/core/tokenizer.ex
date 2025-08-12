defmodule Core.Tokenizer do
  @moduledoc """
  Tokenizer that:
    • normalizes and decontracts input
    • greedily merges known multiword phrases (longest match first)
    • emits %Core.Token{} structs with position/source metadata
    • (optionally) triggers async Brain activation for user input

  Accepts either a raw sentence (binary) or a %Core.SemanticInput{}.
  """

  alias Core.{Token, SemanticInput}
  alias Core.MultiwordMatcher
  alias Core.Contractions
  alias Brain

  # ── Public API ────────────────────────────────────────────────────────────────

  @doc "Tokenizes a %SemanticInput{} in place."
  @spec tokenize(SemanticInput.t()) :: SemanticInput.t()
  def tokenize(%SemanticInput{sentence: s} = input) when is_binary(s) do
    s1   = canonicalize_sentence(s)
    norm = normalize_text(s1)

    {tokens, token_structs} = do_tokenize(norm, input.source || :user)

    if (input.source || :user) == :user do
      activate_brain_async(token_structs)
    end

    %SemanticInput{
      input
      | original_sentence: input.original_sentence || s,
        sentence: norm,
        tokens: tokens,
        token_structs: token_structs
    }
  end

  @doc "Tokenizes a raw sentence and returns a fresh %SemanticInput{}."
  @spec tokenize(binary()) :: SemanticInput.t()
  def tokenize(sentence) when is_binary(sentence) do
    s1   = canonicalize_sentence(sentence)
    norm = normalize_text(s1)

    {tokens, token_structs} = do_tokenize(norm, :user)

    activate_brain_async(token_structs)

    %SemanticInput{
      original_sentence: sentence,
      sentence: norm,
      source: :user,
      tokens: tokens,
      token_structs: token_structs
    }
  end

  # ── Internal ─────────────────────────────────────────────────────────────────

  @spec do_tokenize(binary(), atom()) :: {[String.t()], [Token.t()]}
  defp do_tokenize(sentence, source) when sentence in ["", " "], do: {[], []}

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
          # Use matcher POS override for functional phrases; otherwise []
          pos: MultiwordMatcher.pos_override(phrase)
        }
      end)

    {Enum.map(token_structs, & &1.phrase), token_structs}
  end

  # ── Async Brain activation (deduped; functional phrases skipped) ─────────────

  @spec activate_brain_async([Token.t()]) :: :ok
  defp activate_brain_async(token_structs) do
    token_structs
    |> Enum.map(& &1.phrase)
    |> Enum.uniq()
    |> Enum.reject(&skip_activation?/1)
    |> Enum.each(fn phrase ->
      fun = fn -> safe_get_or_start(phrase) end

      case Process.whereis(Core.TaskSup) do
        nil -> Task.start(fun)
        _   -> Task.Supervisor.start_child(Core.TaskSup, fun)
      end
    end)

    :ok
  end

  defp safe_get_or_start(phrase) do
    try do
      _ = Brain.get_or_start(phrase)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  @spec skip_activation?(String.t()) :: boolean()
  defp skip_activation?(phrase) do
    functional? = match?([_ | _], MultiwordMatcher.pos_override(phrase))
    short?      = String.length(phrase) < 3
    functional? or short?
  end

  # ── Normalization ────────────────────────────────────────────────────────────

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

  @doc """
  Keeps:
    • letters, digits, spaces
    • apostrophes/hyphens when BETWEEN letters/digits (it's, state-of-the-art)
    • periods inside numbers (3.14)
  Strips: control chars and stray punctuation/symbols.
  """
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

  @spec strip_control(binary()) :: binary()
  defp strip_control(s), do: String.replace(s, ~r/[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}]/u, "")

  @spec collapse_ws(binary()) :: binary()
  defp collapse_ws(s), do: String.replace(s, ~r/\s+/u, " ")

  # Remove apostrophes/hyphens at boundaries; keep only when surrounded by alnum.
  @spec keep_word_internals(binary()) :: binary()
  defp keep_word_internals(s) do
    s
    |> String.replace(~r/(?<![\p{L}\p{N}])['-]|['-](?![\p{L}\p{N}])/u, "")
    |> String.replace(~r/(?<!\p{N})\.(?!\p{N})/u, "")
  end

  # Remove remaining non-word chars (except spaces/'-. vetted above)
  @spec strip_outer_punct(binary()) :: binary()
  defp strip_outer_punct(s), do: String.replace(s, ~r/[^\p{L}\p{N}\s'\-\.]/u, "")
end

