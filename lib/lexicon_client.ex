defmodule LexiconClient do
  use Tesla

  @behaviour LexiconClient.Behavior

  plug(Tesla.Middleware.BaseUrl, "https://api.dictionaryapi.dev/api/v2")
  plug(Tesla.Middleware.JSON)
  # 5 seconds
  plug(Tesla.Middleware.Timeout, timeout: 5_000)

  @doc """
  Fetch definitions for a given English word using dictionaryapi.dev.
  """
  def fetch_word(word) when is_binary(word) do
    get("/entries/en/#{URI.encode(word)}")
  end
end
