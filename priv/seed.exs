Mix.Task.run("app.start")

IO.puts("📦 Loading WordNet JSON from priv/wordnet.json...")

# Load and decode the JSON file
json =
  "priv/wordnet.json"
  |> File.read!()
  |> Jason.decode!()

lemma_map = json["lemma"]
synset_map = json["synset"]

IO.puts("🧹 Wiping and reseeding DETS :lemma_index...")
:dets.open_file(:lemma_index, file: ~c"priv/wordnet_lemma_index.dets")
:dets.delete_all_objects(:lemma_index)

Enum.each(lemma_map, fn {lemma_key, synset_ids} ->
  synsets =
    Enum.map(synset_ids, fn sid ->
      case Map.fetch(synset_map, sid) do
        {:ok, synset} ->
          %{
            id: sid,
            pos: synset["pos"],
            words: synset["words"],
            gloss: synset["gloss"],
            examples: Map.get(synset, "examples", []),
            relations: Map.get(synset, "relations", %{})
          }

        :error ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)

  :ok = :dets.insert(:lemma_index, {lemma_key, %{lemma: lemma_key, synsets: synsets}})
end)

:dets.close(:lemma_index)

IO.puts("✅ WordNet seeding complete!")
