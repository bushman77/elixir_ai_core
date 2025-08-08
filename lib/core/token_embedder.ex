defmodule Core.TokenEmbedder do
  def dummy_embed(token) do
    # Create a fixed-size Nx tensor from the token string
    token
    |> :erlang.phash2()
    |> rem(10000)
    |> Integer.to_string()
    |> String.to_charlist()
    |> Enum.map(&(&1 / 255))
    |> Nx.tensor()
    |> Nx.reshape({1, -1}) # Ensure it's 2D
  end
end

