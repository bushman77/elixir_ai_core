defmodule Brain.CuriosityThread do
  @moduledoc """
  Background process that explores and enriches synonyms of activated BrainCells,
  with depth control and prioritization.
  """

  use GenServer
  alias Core.DB
  alias BrainCell
  alias LexiconEnricher

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{explored: MapSet.new(), queue: :queue.new()}, name: __MODULE__)
  end

  def register_activation(word, priority \\ 0) when is_binary(word) do
    GenServer.cast(__MODULE__, {:enqueue, word, priority, 0})
  end

  ## Server Callbacks

  def init(state), do: {:ok, state}

  def handle_cast({:enqueue, word, priority, depth}, %{explored: explored, queue: queue} = state) do
    if MapSet.member?(explored, word) do
      {:noreply, state}
    else
      new_queue = :queue.in({priority, word, depth}, queue)
      {:noreply, %{state | queue: new_queue}}
    end
  end

  def handle_info(:process_queue, %{queue: queue, explored: explored} = state) do
    case :queue.out(queue) do
      {{:value, {priority, word, depth}}, new_queue} ->
        if MapSet.member?(explored, word) do
          {:noreply, %{state | queue: new_queue}}
        else
          Task.start(fn -> do_explore(word, depth) end)
          new_explored = MapSet.put(explored, word)
          Process.send_after(self(), :process_queue, 100) # small delay to avoid busy looping
          {:noreply, %{state | queue: new_queue, explored: new_explored}}
        end

      {:empty, _} ->
        # No more items, wait longer before next check
        Process.send_after(self(), :process_queue, 1_000)
        {:noreply, state}
    end
  end

  def handle_info(:start, state) do
    Process.send_after(self(), :process_queue, 0)
    {:noreply, state}
  end

  defp do_explore(word, depth) when depth < 3 do
    with {:ok, cells} <- DB.get_by_word(word) do
      synonyms =
        cells
        |> Enum.flat_map(& &1.synonyms)
        |> Enum.uniq()
        |> Enum.reject(&too_short_or_common?/1)

      Enum.each(synonyms, fn syn ->
        case DB.exists?(syn) do
          true -> :noop
          false -> 
            IO.puts("🧠 Curious about: #{syn}")
            LexiconEnricher.enrich(syn)
            # Register for next depth of exploration with lower priority
            register_activation(syn, 1)
        end
      end)
    else
      _ -> :noop
    end
  end

  defp do_explore(_word, _depth), do: :ok

  defp too_short_or_common?(word) do
    String.length(word) <= 2 or word in ~w[to and the or of a an is in on at by for with from]
  end
end

