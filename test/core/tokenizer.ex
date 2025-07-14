defmodule Core.TokenizerTest do
  use ExUnit.Case

  alias Core.Tokenizer
  alias Core.DB
  alias BrainCell  # ✅ Schema and GenServer merged here

  setup do
    # ✅ Clear all brain cells before each test
    DB.Repo.delete_all(BrainCell)
    :ok
  end

  test "tokenize/1 returns POS from DB if word is enriched" do
    DB.Repo.insert!(%BrainCell{
      id: "dream|noun|0",
      word: "dream",
      pos: "noun",
      definition: "A sequence of images, ideas, emotions.",
      example: "I had a dream.",
      synonyms: ["vision", "hallucination"],
      antonyms: [],
      type: "lexical",
      activation: 0.0,
      serotonin: 0.0,
      dopamine: 0.0,
      connections: [],
      position: [],
      status: "active"
    })

    assert Tokenizer.tokenize("dream") == [:noun]
  end
end

