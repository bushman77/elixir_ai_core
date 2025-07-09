# priv/dets_test.exs

alias BrainCell

table = :brain
dets_file = ~c"priv/brain.dets"  # DETS expects a charlist for file path

# Open or create DETS table
open_result = :dets.open_file(table, file: dets_file)
IO.inspect(open_result, label: "Open DETS table result")

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

# Insert the tuple {id, word, cell}
insert_result = :dets.insert(table, {cell.id, cell.word, cell})
IO.inspect(insert_result, label: "Insert result")

# Lookup by id — raw output, no pattern matching
lookup_result = :dets.lookup(table, cell.id)
IO.inspect(lookup_result, label: "Raw DETS lookup result by id")

# Lookup by word (linear scan) — raw output
fold_result = :dets.foldl(
  fn {_id, word, cell}, acc ->
    if word == cell.word, do: [cell | acc], else: acc
  end,
  [],
  table
)
IO.inspect(fold_result, label: "Raw DETS foldl result by word")

# Close DETS table
close_result = :dets.close(table)
IO.inspect(close_result, label: "Close DETS table result")

