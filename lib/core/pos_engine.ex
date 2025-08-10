defmodule Core.POSEngine do
  @moduledoc """
  Tags parts of speech for the given SemanticInput using
  multiword POS + greeting overrides + simple heuristics.
  Preserves POS set by MWE merging.
  """

  alias Core.{SemanticInput, Token, MultiwordPOS}

  # Lightweight lexical overrides
  @lex_overrides %{
    "hello"   => :interjection,
    "hi"      => :interjection,
    "hey"     => :interjection,
    "yo"      => :interjection,
    "there"   => :pronoun,
    "thanks"  => :interjection,
    "thank"   => :verb,
    "please"  => :particle,
    "help"    => :verb,
    "weather" => :noun,
    "time"    => :noun,
    "price"   => :noun
  }

  # Pairwise MWE safety net (Tokenizer should merge already; this is a backup)
  @mwes %{
    {"good", "morning"}   => {:greeting_mwe, :interjection},
    {"good", "afternoon"} => {:greeting_mwe, :interjection},
    {"good", "evening"}   => {:greeting_mwe, :interjection},
    {"thank", "you"}      => {:thanks_mwe, :interjection},
    {"what", "time"}      => {:what_time_mwe, :wh},
    {"how", "much"}       => {:how_much_mwe, :wh}
  }

  @greeting_overrides %{
    "hello" => :interjection,
    "hi"    => :interjection,
    "hey"   => :interjection,
    "yo"    => :interjection
  }

  @doc """
  Tags the tokens in a SemanticInput with POS data.
  - Tries to merge MWEs (backup) without clobbering existing POS.
  - Uses MultiwordPOS.lookup/1, then overrides, then heuristics.
  """
  @spec tag(SemanticInput.t()) :: SemanticInput.t()
  def tag(%SemanticInput{token_structs: tokens} = input) do
    tokens =
      tokens
      |> merge_mwes() # if Tokenizer already merged, this keeps them as-is
      |> Enum.with_index()
      |> Enum.map(fn {t, i} ->
        phrase = String.downcase(t.phrase || t.text || "")

        # Preserve POS if already set by MWE merge
        pos =
          cond do
            is_list(t.pos) and t.pos != [] ->
              t.pos

            true ->
              resolve_pos(phrase)
          end

        %Token{t | pos: List.wrap(pos), position: i}
      end)

    %SemanticInput{
      input
      | token_structs: tokens,
        pos_list: Enum.map(tokens, fn t -> t.pos end)
    }
  end

  # ---------- POS resolution chain ----------

  defp resolve_pos(word) do
    # 1) MWEs exposed via MultiwordPOS
    case MultiwordPOS.lookup(word) do
      nil -> resolve_override_or_heuristic(word)
      :unknown -> resolve_override_or_heuristic(word)
      pos -> pos
    end
  end

  defp resolve_override_or_heuristic(word) do
    Map.get(@greeting_overrides, word) ||
      Map.get(@lex_overrides, word) ||
      naive_guess(word)
  end

  # ---------- Backup MWE merge (non-destructive) ----------

  # If tokens are already merged (e.g., "good morning" as one token),
  # we leave them alone. Otherwise, we scan adjacent pairs and merge.
  defp merge_mwes(tokens), do: scan(tokens, [])

  defp scan([t1, t2 | rest], acc) do
    p1 = String.downcase(t1.phrase || t1.text || "")
    p2 = String.downcase(t2.phrase || t2.text || "")

    case Map.get(@mwes, {p1, p2}) do
      {mwe_phrase, mwe_pos} ->
        merged = %Token{
          t1
          | phrase: Atom.to_string(mwe_phrase),
            pos: List.wrap(mwe_pos),
            source: t1.source
        }

        scan(rest, [merged | acc])

      _ ->
        scan([t2 | rest], [t1 | acc])
    end
  end

  defp scan([last], acc), do: Enum.reverse([last | acc])
  defp scan([], acc), do: Enum.reverse(acc)

  # ---------- Heuristics ----------

  defp naive_guess(word) do
    cond do
      word in ~w(what when where who why how) -> :wh
      String.match?(word, ~r/^[\d\.,]+$/) -> :number
      String.ends_with?(word, "ing") -> :verb
      String.ends_with?(word, "ed")  -> :verb
      true -> :noun
    end
  end
end

