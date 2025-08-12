defmodule LexiconClient do
  @moduledoc """
  Client for fetching definitions from dictionaryapi.dev.
  """

  use Tesla

  @behaviour LexiconClient.Behavior

  plug Tesla.Middleware.BaseUrl, "https://api.dictionaryapi.dev/api/v2"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Timeout, timeout: 5_000

  @doc """
  Fetch definitions for a given English word.

  ## Examples

      iex> LexiconClient.fetch_word("hello")
      {:ok, %Tesla.Env{status: 200, body: ...}}

  """
  @spec fetch_word(String.t()) :: {:ok, Tesla.Env.t()} | {:error, Tesla.Error.t()}
  def fetch_word(word) when is_binary(word) do
    get("/entries/en/#{URI.encode(word)}")
  end
end

