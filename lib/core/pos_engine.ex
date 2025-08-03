defmodule Core.POSEngine do
  alias Core.{SemanticInput, Token}
  alias Brain

  @fallback_pos "unknown"

  def tag(%SemanticInput{token_structs: tokens, cells: cells} = input) do
    pos_list = Enum.map(tokens, fn %Token{phrase: word} = token ->
      pos = find_pos(word, cells)
      {word, pos}
    end)

    %{input | pos_list: pos_list}
  end

  defp find_pos(word, cells) do
    case Enum.find(cells, fn cell -> cell.word == word end) do
      nil -> @fallback_pos
      %{} = cell ->
        case cell.pos do
          nil -> @fallback_pos
          pos when is_list(pos) -> List.first(pos)
          pos -> pos
        end
    end
  end
end

