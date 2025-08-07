defmodule Core.POSEngine do
  @moduledoc """
  Tags parts of speech for the given SemanticInput using
  multiword POS and basic heuristics, with greeting overrides.
  """

  alias Core.{SemanticInput, Token, MultiwordPOS}

  @greeting_overrides %{
    "hello" => :interjection,
    "hi"    => :interjection,
    "hey"   => :interjection,
    "yo"    => :interjection
  }

  @doc """
  Tags the tokens in a SemanticInput with POS data.
  """
  def tag(%SemanticInput{token_structs: tokens} = semantic) do
    tagged =
      tokens
      |> Enum.map(&tag_token/1)

    %{ semantic
       | token_structs: tagged,
         pos_list: Enum.map(tagged, & &1.pos) }
  end

  defp tag_token(%Token{phrase: phrase} = token) do
    pos_list = phrase
               |> String.downcase()
               |> override_or_lookup()
               |> List.wrap()          # ensure it’s always a list
    %{ token | pos: pos_list }
  end

  # 1) Greeting override
  defp override_or_lookup(word) do
    case @greeting_overrides[word] do
      nil -> lookup_or_naive(word)
      override_pos -> override_pos
    end
  end

  # 2) MultiwordPOS dictionary
  defp lookup_or_naive(word) do
    case MultiwordPOS.lookup(word) do
      :unknown -> naive_guess(word)
      pos       -> pos
    end
  end

  # 3) Fallback heuristics
  defp naive_guess(word) do
    cond do
      String.ends_with?(word, "ing") -> :verb
      String.ends_with?(word, "ed")  -> :verb
      String.length(word) <= 3       -> :preposition
      true                            -> :noun
    end
  end
end

