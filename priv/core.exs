# priv/dets_test.exs

alias BrainCell
alias Core.DB

# Sample BrainCell struct
cell = %BrainCell{
  id: "test|noun|1",
  word: "test",
  pos: :noun,
  definition: "A test definition",
  example: "This is a test example.",
  synonyms: [],
  antonyms: [],
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

Core.DB.put(cell)
t = Core.DB.get(cell.word)
IO.inspect(t)
g = Core.DB.get("test", :word)
IO.inspect(g)
