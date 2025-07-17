defmodule Core.DB do
  use Ecto.Repo,
    otp_app: :elixir_ai_core,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query
  alias BrainCell

  @doc """
  Checks if any brain cell exists for the given word.
  """
  def has_word?(word) when is_binary(word) do
    query =
      from b in BrainCell,
        where: b.word == ^word,
        select: 1

    exists?(query)
  end

  @doc """
  Checks if a brain cell exists for the given id.
  """
  def cell_exists?(id) do
    query =
      from b in BrainCell,
        where: b.id == ^id,
        select: 1

    exists?(query)
  end
end

