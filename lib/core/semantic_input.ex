defmodule Core.SemanticInput do
  @moduledoc "Pipeline state passed through Core."

  alias Core.Token
  alias BrainCell

  @type intent_t :: atom() | nil
  @type mood_t :: atom() | nil
  @type source_t :: :user | :system | :test | atom() | nil

  @type t :: %__MODULE__{
          # NEW: preserve exact user text
          original_sentence: String.t() | nil,
          # Normalized/processed sentence used by the pipeline
          sentence: String.t() | nil,

          # Tokens and rich token data
          tokens: [String.t()],
          token_structs: [Token.t()],

          # Brain / POS context
          cells: [BrainCell.t()] | list(),
          pos_list: list(),

          # Predicted labels
          intent: intent_t,
          keyword: String.t() | nil,
          confidence: float() | nil,
          mood: mood_t,

          # Supervision (gold) labels
          gold_intent: atom() | String.t() | nil,

          # Matcher + planning context
          phrase_matches: [String.t()],
          source: source_t,
          activation_summary: map() | nil,
          pattern_roles: map(),

          # Response planning/runtime conveniences
          cell: BrainCell.t() | map() | nil,
          response: String.t() | nil,
          planned_response: String.t() | nil
        }

  defstruct [
    # NEW
    :original_sentence,
    # existing
    :sentence,
    :tokens,
    :token_structs,
    :cells,
    :pos_list,
    :intent,
    # NEW (already in your version, reaffirmed)
    :gold_intent,
    :keyword,
    :confidence,
    :mood,
    :phrase_matches,
    :source,
    :activation_summary,
    :pattern_roles,
    :cell,
    :response,
    :planned_response
  ]
end

