# Open the DETS table
:dets.open_file(:lemma_index, file: ~c"priv/wordnet_lemma_index.dets")
# Delete the existing "how" entry if any
:dets.delete(:lemma_index, "how")

# Now insert the fresh "how" entry without binary encoding
entry = {
  "how",
  [
    %{
      lemma: "how",
      synsets: [
        %{
          id: "r000001",
          pos: "r",
          gloss: "To what degree.",
          examples: ["How often do you practice?"],
          relations: %{}
        },
        %{
          id: "r000002",
          pos: "r",
          gloss: "In what manner.",
          examples: ["How do you solve this puzzle?"],
          relations: %{}
        },
        %{
          id: "r000003",
          pos: "r",
          gloss: "In what state.",
          examples: ["How are you?"],
          relations: %{}
        },
        %{
          id: "r000004",
          pos: "r",
          gloss:
            "Used as a modifier to indicate surprise, delight, or other strong feelings in an exclamation.",
          examples: ["How very interesting!"],
          relations: %{}
        }
      ]
    },
    %{
      lemma: "how",
      synsets: [
        %{
          id: "c000001",
          pos: "c",
          gloss: "The manner or way that.",
          examples: ["I remember how I solved this puzzle."],
          relations: %{}
        },
        %{
          id: "c000002",
          pos: "c",
          gloss: "That, the fact that, the way that.",
          examples: [],
          relations: %{}
        }
      ]
    },
    %{
      lemma: "how",
      synsets: [
        %{
          id: "i000001",
          pos: "i",
          gloss: "A greeting, used in representations of Native American speech.",
          examples: ["How!"],
          relations: %{}
        }
      ]
    }
  ]
}

:dets.insert(:lemma_index, entry)
:dets.sync(:lemma_index)
:dets.close(:lemma_index)

