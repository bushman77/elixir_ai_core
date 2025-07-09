defmodule LexiconClientTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  @scraped %{
    "word" => "hello",
    "meanings" => [
      %{
        "partOfSpeech" => "noun",
        "definitions" => [
          %{
            "definition" => "\"Hello!\" or an equivalent greeting.",
            "synonyms" => [],
            "antonyms" => []
          }
        ]
      },
      %{
        "partOfSpeech" => "verb",
        "definitions" => [
          %{"definition" => "To greet with \"hello\".", "synonyms" => [], "antonyms" => []}
        ]
      }
    ]
  }

  test "fetch_word/1 returns real data from dictionary API" do
    word = "hello"
    assert {:ok, %{status: 200, body: body}} = LexiconClient.fetch_word(word)
    first = hd(body)
    assert Map.has_key?(first, "word")
    assert Map.has_key?(first, "meanings")
  end

  test "parses mocked dictionary response into BrainCells" do
    LexiconClientMock
    |> expect(:fetch_word, fn "hello" ->
      {:ok, %{status: 200, body: [@scraped]}}
    end)

    assert {:ok, %{status: 200, body: [entry]}} = LexiconClientMock.fetch_word("hello")

    meanings = entry["meanings"]

    braincells =
      meanings
      |> Enum.flat_map(fn %{"partOfSpeech" => pos_str, "definitions" => defs} ->
        pos = String.to_atom(pos_str)

        Enum.with_index(defs, 1)
        |> Enum.map(fn {defn, idx} ->
          %BrainCell{
            id: "hello|#{pos}|#{idx}",
            word: "hello",
            pos: pos,
            definition: defn["definition"],
            example: defn["example"] || "",
            synonyms: defn["synonyms"] || [],
            antonyms: defn["antonyms"] || [],
            type: nil,
            activation: 0.0,
            serotonin: 1.0,
            dopamine: 1.0,
            connections: [],
            position: {0.0, 0.0, 0.0},
            status: :active,
            last_dose_at: nil,
            last_substance: nil
          }
        end)
      end)

    assert length(braincells) == 2
  end
end
