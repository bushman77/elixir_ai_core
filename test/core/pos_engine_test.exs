defmodule Core.POSEngineTest do
  use ExUnit.Case, async: true

  alias Core.POSEngine
  alias Core.SemanticInput
  alias Core.Token

  # --- helpers ---------------------------------------------------------------

  defp sem_from(words_or_tokens) do
    token_structs =
      words_or_tokens
      |> Enum.with_index()
      |> Enum.map(fn
        {{phrase, pos}, i} -> %Token{phrase: phrase, text: phrase, pos: List.wrap(pos), position: i, source: :test}
        {phrase, i}        -> %Token{phrase: phrase, text: phrase, pos: [],               position: i, source: :test}
      end)

    %SemanticInput{
      sentence: words_or_tokens |> Enum.map(&elem(&1, 0)) |> Enum.join(" "),
      token_structs: token_structs,
      pos_list: []
    }
  end

  defp phrases(out), do: Enum.map(out.token_structs, & &1.phrase)
  defp poses(out),    do: Enum.map(out.token_structs, & &1.pos)
  defp positions(out),do: Enum.map(out.token_structs, & &1.position)

  # --- tests -----------------------------------------------------------------

  test "preserves existing POS if already set" do
    input = sem_from([{"hello", [:interjection]}, {"there", []}])
    out = POSEngine.tag(input)

    assert hd(poses(out)) == [:interjection]
    # second token should be resolved (override/heuristic), but first preserved
    refute Enum.at(poses(out), 1) == []
  end

  test "greeting overrides: hello/hi/hey/yo -> :interjection" do
    for word <- ~w(hello hi hey yo) do
      out = POSEngine.tag(sem_from([{word, []}]))
      assert poses(out) == [[:interjection]]
    end
  end

  test "lex overrides: please -> :particle, help -> :verb, weather/time/price -> :noun" do
    assert POSEngine.tag(sem_from([{"please", []}])) |> poses() == [[:particle]]
    assert POSEngine.tag(sem_from([{"help", []}]))   |> poses() == [[:verb]]
    assert POSEngine.tag(sem_from([{"weather", []}]))|> poses() == [[:noun]]
    assert POSEngine.tag(sem_from([{"time", []}]))   |> poses() == [[:noun]]
    assert POSEngine.tag(sem_from([{"price", []}]))  |> poses() == [[:noun]]
  end

  test "heuristics: wh words, numbers, and simple verb suffixes" do
    assert POSEngine.tag(sem_from([{"how", []}]))     |> poses() == [[:wh]]
    assert POSEngine.tag(sem_from([{"42", []}]))      |> poses() == [[:number]]
    assert POSEngine.tag(sem_from([{"3.14", []}]))    |> poses() == [[:number]]
    assert POSEngine.tag(sem_from([{"running", []}])) |> poses() == [[:verb]]
    assert POSEngine.tag(sem_from([{"tested", []}]))  |> poses() == [[:verb]]
  end

  test "backup MWE merge: thank + you => thanks_mwe with :interjection" do
    input = sem_from([{"thank", []}, {"you", []}])
    out = POSEngine.tag(input)

    assert phrases(out) == ["thanks_mwe"]         # merged to one token
    assert poses(out)    == [[:interjection]]     # POS from MWE map
    assert positions(out)== [0]                   # positions reindexed
    assert out.pos_list  == [[:interjection]]     # pos_list mirrors token_structs
  end

  test "backup MWE merge: what + time => what_time_mwe with :wh" do
    input = sem_from([{"what", []}, {"time", []}])
    out = POSEngine.tag(input)

    assert phrases(out) == ["what_time_mwe"]
    assert poses(out)    == [[:wh]]
  end

  test "already merged MWEs stay untouched (non-destructive)" do
    input = sem_from([{"good morning", []}])  # tokenized as one token already
    out = POSEngine.tag(input)

    assert phrases(out) == ["good morning"]
    assert length(out.token_structs) == 1
  end

  test "case-insensitive resolution" do
    out = POSEngine.tag(sem_from([{"HeLLo", []}, {"THERE", []}]))
    assert poses(out) == [[:interjection], [[:pronoun] |> hd() |> then(fn _ -> [:pronoun] end)] |> hd()]
    # Simpler: assert first is interjection, second is not empty:
    assert hd(poses(out)) == [:interjection]
    refute Enum.at(poses(out), 1) == []
  end

  test "positions are sequential after tagging (even with merges)" do
    input = sem_from([{"thank", []}, {"you", []}, {"please", []}])
    out = POSEngine.tag(input)

    assert positions(out) == Enum.to_list(0..(length(out.token_structs) - 1))
  end

  test "pos_list mirrors token_structs.pos exactly" do
    out = POSEngine.tag(sem_from([{"hello", []}, {"time", []}]))
    assert out.pos_list == poses(out)
  end
end

