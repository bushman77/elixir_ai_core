# priv/lexicon_client_fetch.exs

# Ensure your app and dependencies are started if needed
Application.ensure_all_started(:your_app_name)

word = System.argv() |> List.first() || "example"

case LexiconClient.fetch_word(word) do
  {:ok, response} ->
    IO.puts("Raw response for word: #{word}")
    IO.inspect(response, pretty: true)
  {:error, reason} ->
    IO.puts("Failed to fetch word: #{word}")
    IO.inspect(reason)
end

