defmodule Core.POSEngine do
  @moduledoc """
  Tags parts of speech for the given SemanticInput using multiword POS and basic heuristics.
  """

  alias Core.SemanticInput
  alias Core.Token
  alias Core.MultiwordPOS

  @doc """
  Tags the tokens in a SemanticInput with POS data.
  """
  def tag(%SemanticInput{token_structs: tokens} = semantic) do
    tagged_tokens =
      Enum.map(tokens, fn token ->
        %Token{token |
          pos: guess_pos(token.phrase)
        }
      end)

    %{semantic | token_structs: tagged_tokens, pos_list: Enum.map(tagged_tokens, & &1.pos)}
  end

  # POS guessing can be upgraded to use a dictionary, ML model, or rule-based tags
  defp guess_pos(word) when is_binary(word) do
    case MultiwordPOS.lookup(word) do
      :unknown -> naive_guess(word)
      pos -> [pos]
    end
  end

  # Naive POS rules (can be replaced later with LexiconEnricher logic)
  defp naive_guess(word) do
    cond do
      String.ends_with?(word, "ing") -> [:verb]
      String.ends_with?(word, "ed") -> [:verb]
      String.length(word) <= 3 -> [:preposition, :conjunction]
      true -> [:noun] # Default fallback
    end
  end
end

