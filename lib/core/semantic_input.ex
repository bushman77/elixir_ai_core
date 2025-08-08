defmodule Core.SemanticInput do
  defstruct [
    :sentence,            # Raw input string
    :tokens,              # ["how", "are", "you"]
    :token_structs,       # [%Token{...}]
    :cells,               # [%BrainCell{}, ...]
    :pos_list,            # [{"how", "adv"}, ...]
    :intent,              # :greeting, :question
    :gold_intent,
    :keyword,             # "how"
    :confidence,          # 0.92
    :mood,                # :neutral, :curious, etc.
    :phrase_matches,      # ["how are you"]
    :source,              # :user
    :activation_summary,  # %{top_cell: ..., score: ...}
    :pattern_roles,       # %{"you" => :subject}
    :cell,                # Optional BrainCell used in response planning
    :response             # Final planned response text
  ]
end

