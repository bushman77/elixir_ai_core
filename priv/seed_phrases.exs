# priv/seed_phrases.exs

alias Brain
alias BrainCell

defmodule Seeder do
    def put_cell(word) do
          case Brain.get(Brain, word) do
                  nil ->
                      cell = %BrainCell{
                                  id: word,
                                  connections: [],
                                  activation: 0.0,
                                  type: :word,
                                  position: {0, 0},
                                  serotonin: 0.5,
                                  dopamine: 0.5,
                                  last_dose_at: nil,
                                  last_substance: nil
                                }

                      Brain.put(Brain, cell)
                      cell

                    cell ->
                      cell
                  end
        end

    def connect_cells(from_word, to_word) do
          Brain.connect(Brain, from_word, to_word, 1.0, 100)
        end

    def seed_phrases!(phrases) do
          Brain.clear(Brain)

          phrases
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()
          |> Enum.each(fn phrase ->
                  words = String.split(phrase)
                  Enum.reduce(words, nil, fn word, prev ->
                            put_cell(word)
                            if prev, do: connect_cells(prev, word)
                            word
                          end)
                end)

          IO.puts("✅ Seeded #{length(phrases)} phrases from file")
        end
end

# 📄 Load phrases from "all_phrases.txt"
file_path = "./priv/all_phrases.txt"

phrases =
    file_path
  |> File.read!()
  |> String.split("\n")

Seeder.seed_phrases!(phrases)

