defmodule Core.IntentResolver do
  @moduledoc """
  Resolves intent from a SemanticInput struct.
  Falls back to IntentMatrix if classifier confidence is too low.
  """

  alias Core.IntentMatrix
  alias Core.SemanticInput

  @fallback_threshold 1.2

  def resolve_intent(%SemanticInput{intent: intent, confidence: conf} = semantic)
      when intent != :unknown and conf >= @fallback_threshold do
    %{
      intent: intent,
      confidence: conf,
      keyword: semantic.keyword,
      tokens: semantic.tokens,
      source: :classifier
    }
  end

  def resolve_intent(%SemanticInput{tokens: tokens, keyword: keyword}) do
    fallback = IntentMatrix.classify(tokens)

    %{
      intent: fallback.intent,
      confidence: fallback.confidence,
      keyword: fallback.keyword || keyword,
      tokens: tokens,
      source: :matrix
    }
  end
end

