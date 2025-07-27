defmodule Core.IntentResolver do
  alias Core.IntentClassifier
  alias Core.IntentMatrix

  @fallback_threshold 1.2

  @doc """
  Resolves intent using IntentClassifier, with fallback to IntentMatrix if confidence is low.
  Returns a full intent object with keyword, intent, confidence, and source.
  """
  def resolve_intent(tokens) when is_list(tokens) do
    classifier = IntentClassifier.classify(tokens)

    if classifier.confidence >= @fallback_threshold do
      Map.put(classifier, :source, :classifier)
    else
      matrix = IntentMatrix.classify(tokens)

      %{
        intent: matrix.intent,
        confidence: matrix.confidence,
        tokens: tokens,
        keyword: classifier.keyword,     # still pass keyword if available
        source: :matrix
      }
    end
  end
end

