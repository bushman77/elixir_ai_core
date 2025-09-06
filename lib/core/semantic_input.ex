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

  # Orthogonal speech-act annotations
  @type speech_act_t :: :question | :statement | :command | :fragment | :exclamation | atom() | nil
  @type question_kind_t :: :wh | :polar | :choice | :elliptical | :rhetorical | atom() | nil

  @type t :: %__MODULE__{
          original_sentence: String.t() | nil,
          sentence: String.t() | nil,
          tokens: [String.t()],
          token_structs: [Token.t()],
          cells: [BrainCell.t()] | list(),
          pos_list: list(),
          intent: intent_t,
          keyword: String.t() | nil,
          confidence: float() | nil,
          mood: mood_t,
          gold_intent: atom() | String.t() | nil,
          phrase_matches: [String.t()],
          source: source_t,
          activation_summary: map() | nil,
          pattern_roles: map(),
          cell: BrainCell.t() | map() | nil,
          response: String.t() | nil,
          planned_response: String.t() | nil,
          speech_act: speech_act_t,
          question_kind: question_kind_t,
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
    :speech_act,
    :question_kind,
    :llm_ctx,
    :llm_model,
    :llm_system
  ]

  # ------------------------------------------------------------------------
  # SAFE sanitize: only operate on strings; keep token_structs as tokens
  # ------------------------------------------------------------------------
  def sanitize(%__MODULE__{} = sem) do
    # Ensure we have token structs; if only strings exist, wrap them.
    token_structs =
      case sem.token_structs do
        list when is_list(list) and list != [] -> list
        _ -> Enum.map(sem.tokens || [], &to_token_struct/1)
      end

    pruned_structs =
      token_structs
      |> Enum.reject(&token_from_console?/1)
      |> Enum.reject(fn t ->
        s = token_string(t)
        blank_str?(s)
      end)

    cleaned_tokens =
      pruned_structs
      |> Enum.map(&token_string/1)
      |> Enum.map(&String.trim/1)

    %__MODULE__{sem | token_structs: pruned_structs, tokens: cleaned_tokens}
  end

  # Convenience: set speech-act pair
  def with_speech_act(%__MODULE__{} = si, {sa, kind}),
    do: %{si | speech_act: sa, question_kind: kind}

  # ------------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------------

  # Always extract a string from a token/thing
  defp token_string(%Token{} = t), do: (t.phrase || t.text || "")
  defp token_string(s) when is_binary(s), do: s
  defp token_string(other), do: Kernel.to_string(other)

  defp blank_str?(s) when is_binary(s), do: s == "" or Regex.match?(~r/^\s*$/, s)
  defp blank_str?(_), do: true

  defp token_from_console?(%Token{source: src}), do: src in [:console, :command, :debug]
  defp token_from_console?(_), do: false

  defp to_token_struct(%Token{} = t), do: t
  defp to_token_struct(s) when is_binary(s), do: %Token{text: s, pos: []}
  defp to_token_struct(other), do: %Token{text: Kernel.to_string(other), pos: []}
end

