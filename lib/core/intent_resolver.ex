defmodule Core.IntentResolver do
  alias Core.IntentClassifier
  alias Core.IntentMatrix

  @fallback_threshold 1.2

  @doc """
  Resolves intent from enriched tokens (ideally containing braincell metadata).
  Falls back to IntentMatrix if classifier confidence is too low.
  Always returns a %{
    intent: atom,
    confidence: float,
    keyword: string | nil,
    source: :classifier | :matrix,
    tokens: list
  } structure.
  """
def resolve_intent(tokens) when is_list(tokens) do
  case IntentClassifier.classify(tokens) do
    {:ok, %{confidence: confidence} = result} when confidence >= @fallback_threshold ->
      Map.put(result, :source, :classifier)

    {:ok, %{keyword: keyword}} ->
      fallback = IntentMatrix.classify(tokens)

      %{
        intent: fallback.intent,
        confidence: fallback.confidence,
        keyword: keyword,
        tokens: tokens,
        source: :matrix
      }

    other ->
      IO.inspect(other, label: "⚠️ Unexpected classifier output")
      %{
        intent: :unknown,
        confidence: 0.0,
        keyword: nil,
        tokens: tokens,
        source: :none
      }
  end
end

end

