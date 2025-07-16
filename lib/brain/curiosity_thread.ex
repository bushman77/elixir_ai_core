defmodule Brain.CuriosityThread do
  @moduledoc """
  Background process that explores and enriches direct synonyms of activated BrainCells.
  """

  use GenServer
  alias Core.DB
  alias BrainCell
  alias LexiconEnricher

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %MapSet{}, name: __MODULE__)
  end

  def register_activation(word) when is_binary(word) do
    GenServer.cast(__MODULE__, {:explore, word})
  end

  ## Server Callbacks

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:explore, word}, explored) do
    if MapSet.member?(explored, word) do
      {:noreply, explored} # Already explored
    else
      Task.start(fn -> do_explore(word) end)
      {:noreply, MapSet.put(explored, word)}
    end
  end

  ## Exploration Logic

  defp do_explore(word) do
    with {:ok, cells} <- DB.get_by_word(word) do
      cells
      |> Enum.flat_map(& &1.synonyms)
      |> Enum.uniq()
      |> Enum.reject(&too_short_or_common?/1)
      |> Enum.each(fn syn ->
        case DB.exists?(syn) do
          true -> :noop
          false ->
            IO.puts("🧠 Curious about: #{syn}")
            LexiconEnricher.enrich(syn)
        end
      end)
    else
      _ -> :noop
    end
  end

  defp too_short_or_common?(word) do
    String.length(word) <= 2 or word in ~w[to and the or of a an is in on at by for with from]
  end
end

