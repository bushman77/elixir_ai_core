defmodule Core.SemanticInput do
  @moduledoc "Pipeline state passed through Core."

  alias Core.Token
  alias BrainCell

  @type intent_t :: atom() | nil
  @type mood_t :: atom() | nil
  @type source_t :: :user | :system | :test | atom() | nil
  @type llm_ctx_t :: [integer] | nil
  @type llm_model_t :: String.t() | nil
  @type llm_system_t :: String.t() | nil

  # NEW: orthogonal speech-act axis
  @type speech_act_t :: :question | :statement | :command | :fragment | :exclamation | atom() | nil
  @type question_kind_t :: :wh | :polar | :choice | :elliptical | :rhetorical | atom() | nil

  @type t :: %__MODULE__{
          # Preserve exact user text
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
          planned_response: String.t() | nil,

          # NEW: speech-act annotations (form, not meaning)
          speech_act: speech_act_t,
          question_kind: question_kind_t,

          # ── LLM session state ─────────────────────────────────────────────
          llm_ctx: llm_ctx_t,
          llm_model: llm_model_t,
          llm_system: llm_system_t
        }

  defstruct [
    :original_sentence,
    :sentence,
    :tokens,
    :token_structs,
    :cells,
    :pos_list,
    :intent,
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
    :planned_response,
    # NEW
    :speech_act,
    :question_kind,
    # LLM
    :llm_ctx,
    :llm_model,
    :llm_system
  ]

  # Keep your existing sanitize
  def sanitize(%__MODULE__{token_structs: toks} = input) do
    pruned =
      toks
      |> Enum.reject(&(&1.source in [:console, :command, :debug]))
      |> Enum.reject(&(&1.phrase =~ ~r/^\s*$/))

    %{input | token_structs: pruned}
  end

  # Convenience: set speech-act pair
  def with_speech_act(%__MODULE__{} = si, {sa, kind}),
    do: %{si | speech_act: sa, question_kind: kind}
end

