defmodule Core.Token do
  defstruct [
    :phrase,
    :text,           # string
    :input_text,     # full sentence
    :is_phrase,      # bool
    :index,          # position
    :pos,            # optional: ["ADV"], etc.
    :position,
    :embedding,      # optional: vector
    :embedded_vector,
    :source          # :tokenizer, :enricher, etc.
  ]
end

