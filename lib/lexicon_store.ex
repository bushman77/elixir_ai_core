defmodule LexiconStore do
  @table :lemma_index

  def put(word, synsets) when is_binary(word) do
    :dets.insert(@table, {word, :erlang.term_to_binary(synsets)})
  end

  def get(word) when is_binary(word) do
    case :dets.lookup(@table, word) do
      [{^word, binary}] -> :erlang.binary_to_term(binary)
      [] -> nil
    end
  end

  def exists?(word) do
    :dets.lookup(@table, word) != []
  end
end
