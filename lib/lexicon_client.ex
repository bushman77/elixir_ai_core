defmodule LexiconClient do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://api.dictionaryapi.dev/api/v2")
  plug(Tesla.Middleware.JSON)

  @doc """
  Fetch definitions for a given English word using dictionaryapi.dev.
  """
  def fetch_word(word) do
    get("/entries/en/#{word}")
  end
end
