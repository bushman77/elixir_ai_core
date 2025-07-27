defmodule Core.Token do
  @moduledoc """
  Represents a token or phrase unit with optional semantic enrichment.
  """

  defstruct [
    :phrase,
    :index,
    pos: nil,
    keyword: nil,
    intent: nil,
    confidence: nil,
mood: nil,
enriched_from: nil,
embedded_vector: nil

  ]
end

