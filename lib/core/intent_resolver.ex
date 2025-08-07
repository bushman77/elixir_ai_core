defmodule Core.IntentResolver do
  @moduledoc """
  Resolves intent from a SemanticInput struct.
  Falls back to IntentMatrix if classifier confidence is too low.
  """

  alias Core.IntentMatrix
  alias Core.SemanticInput

  @fallback_threshold 1.2

  @doc """
  Resolves or upgrades the intent classification for a given SemanticInput.

  If the input already has a high-confidence intent, it is preserved.
  Otherwise, it falls back to the IntentMatrix.
  """
  def resolve_intent(%SemanticInput{} = semantic) do
    if semantic.intent != :unknown and semantic.confidence >= @fallback_threshold do
      %SemanticInput{semantic | source: :classifier}
    else
      fallback = IntentMatrix.classify(semantic.tokens)

      %SemanticInput{
        semantic
        | intent: fallback.intent,
          confidence: fallback.confidence,
          keyword: fallback.keyword || semantic.keyword,
          source: :matrix
      }
    end
  end
end

