defmodule ElixirAiCore.WordNetTest do
  use ExUnit.Case

  alias ElixirAiCore.WordNet

  setup_all do
    {:ok, _} = :dets.open_file(:lemma_index, file: ~c"priv/wordnet_lemma_index.dets")
    on_exit(fn -> :dets.close(:lemma_index) end)
    :ok
  end

  test "lookup returns synsets for a valid word" do
    result = WordNet.lookup("run")

    result
    |> IO.inspect()

    assert is_map(result)
    assert result.lemma == "run"
    assert length(result.synsets) > 0
  end

  test "lookup handles multiple parts of speech" do
    all_synsets = WordNet.lookup_all("run")
    assert length(all_synsets) > 1
    verbs = Enum.filter(all_synsets, &(&1.pos == "v"))
    nouns = Enum.filter(all_synsets, &(&1.pos == "n"))
    assert length(verbs) > 0
    assert length(nouns) > 0
  end

  test "lookup returns empty for unknown word" do
    assert WordNet.lookup("blarfblat") == nil
    assert WordNet.lookup_all("blarfblat") == []
  end

  test "can lookup with full key like 'n.truth'" do
    result = :dets.lookup(:lemma_index, "n.truth")
    assert length(result) == 1
    [{_, data}] = result
    assert is_map(data)
    assert data.lemma == "truth"
  end
end
