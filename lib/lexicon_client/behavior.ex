defmodule LexiconClient.Behavior do
  @callback fetch_word(String.t()) :: {:ok, map()} | {:error, term()}
end
