alias Core.DB
cell = %BrainCell{
  id: "test|noun|1",
  word: "test",
  pos: :noun,
  definition: "A procedure for evaluation",
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

DB.put(cell)
IO.inspect(DB.get(cell.word), label: "Manually inserted cell")

