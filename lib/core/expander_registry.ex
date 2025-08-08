defmodule Core.ExpanderRegistry do
  use GenServer

  @type expander :: %{
          id: binary(),
          name: String.t(),
          module: module(),
          init_args: list(),
          triggers: list(atom()),
          status: :new | :loaded | :error
        }

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(state) do
    # Optionally preload from DETS
    {:ok, load_from_dets()}
  end

  def register(expander) do
    GenServer.cast(__MODULE__, {:register, expander})
  end

  def trigger(:evaluation_complete, context) do
    GenServer.cast(__MODULE__, {:trigger, :evaluation_complete, context})
  end

  def handle_cast({:register, expander}, state) do
    :dets.insert(:expander_store, {expander.id, expander})
    {:noreply, Map.put(state, expander.id, expander)}
  end

  def handle_cast({:trigger, event, context}, state) do
    Enum.each(state, fn {_id, %{module: mod, triggers: triggers}} ->
      if event in triggers and function_exported?(mod, :expand, 1) do
        spawn(fn -> apply(mod, :expand, [context]) end)
      end
    end)

    {:noreply, state}
  end

  defp load_from_dets() do
    :dets.open_file(:expander_store, [type: :set, file: 'expander_store.dets'])
    :dets.tab2list(:expander_store)
    |> Enum.into(%{}, fn {id, expander} -> {id, expander} end)
  end
end

