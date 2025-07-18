defmodule Core.MultiwordMatcher do
  alias Core.MultiwordPOS

  def extract_head_tail(input) when is_binary(input) do
    phrase = Enum.find(MultiwordPOS.phrases(), fn p -> String.contains?(input, p) end)

    if phrase do
      [head, tail] = String.split(input, phrase, parts: 2, trim: true)
      head_tokens = if String.trim(head) != "", do: String.split(head), else: []
      tail_tokens = if String.trim(tail) != "", do: String.split(tail), else: []
      token = %{word: phrase, pos: [MultiwordPOS.lookup(phrase)]}
      head_tokens ++ [token] ++ tail_tokens
    else
      String.split(input)
    end
  end
end

