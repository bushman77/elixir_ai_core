defmodule LlamaClient do
  use Tesla
  plug Tesla.Middleware.BaseUrl, "http://localhost:11434"
  plug Tesla.Middleware.JSON

  def generate(prompt, context \\ nil) do
    context = Brain.context()
    payload =
      %{model: "llama3.1:8b", prompt: prompt, stream: false}
      |> maybe_add_context(context)

    post("/api/generate", payload)
    |> Brain.context_update()
  end

  defp maybe_add_context(payload, nil), do: payload
  defp maybe_add_context(payload, ctx), do: Map.put(payload, :context, ctx)
end
