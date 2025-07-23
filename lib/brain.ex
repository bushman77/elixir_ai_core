defmodule Brain do
  use GenServer

  alias Core.DB
  alias BrainCell
  alias LexiconEnricher

  ## Public API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets a BrainCell process for the given word.
  Checks registry, loads from DB, or enriches + starts process as fallback.
  """
def get_or_start(word) when is_binary(word) do
  word_id = String.downcase(word)

  # Start all from Registry if already running
  case Registry.lookup(Core.Registry, word_id) do
    [{pid, _} | _] ->
      {:ok, pid}  # Just return the first one for now, or enhance this logic

    [] ->
      # Try load from DB
      case DB.get_braincells_by_word(word_id) do
        [] ->
          # Try enrich from external source
          case LexiconEnricher.enrich(word_id) do
            {:ok, cells} when is_list(cells) ->
              Enum.each(cells, &BrainCell.start_link/1)
              {:ok, :started}

            _ ->
              {:error, :not_found}
          end

        cells ->
          Enum.each(cells, &BrainCell.start_link/1)
          {:ok, :started}
      end
  end
end

  ## Server Callbacks and other functions omitted for brevity...

  defp safe_status(pid) do
    try do
      BrainCell.status(pid)
    catch
      _, _ -> {:error, :crashed}
    end
  end
end

