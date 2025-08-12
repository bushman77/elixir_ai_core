defmodule Core.MiniIntent.Server do
  @moduledoc "Hot in-memory MiniIntent with retrain + reload."
  use GenServer
  alias Core.MiniIntent

  def start_link(opts \\ []), do:
    GenServer.start_link(__MODULE__, :ok, Keyword.merge([name: __MODULE__], opts))

  def predict(sentence, thr \\ 0.55), do:
    GenServer.call(__MODULE__, {:predict, sentence, thr}, 5_000)

  # One-liners you asked for:
  def retrain_from_db(opts \\ []),    do: GenServer.cast(__MODULE__, {:retrain, :db, opts})
  def retrain_from_brain(opts \\ []), do: GenServer.cast(__MODULE__, {:retrain, :brain, opts})
  def reload(),                       do: GenServer.cast(__MODULE__, :reload)
  def status(),                       do: GenServer.call(__MODULE__, :status)

  @impl true
  def init(:ok) do
    slmp = MiniIntent.prepare()
    {:ok, %{state: slmp, training: :idle, last_summary: load_summary()}}
  end

  @impl true
  def handle_call({:predict, s, thr}, _from, %{state: slmp} = st) do
    {:reply, MiniIntent.infer(slmp, s, thr), st}
  end

  @impl true
  def handle_call(:status, _from, st) do
    {:reply, %{training: st.training, last_summary: st.last_summary}, st}
  end

  @impl true
  def handle_cast({:retrain, source, opts}, st) do
    if st.training == :running do
      {:noreply, st}
    else
      parent = self()

      Task.start(fn ->
        try do
          case source do
            :db    -> MiniIntent.retrain_from_db!(opts)
            :brain -> MiniIntent.retrain_from_brain!(opts)
          end
          send(parent, :_retrain_done)
        rescue
          e -> send(parent, {:_retrain_failed, Exception.message(e)})
        end
      end)

      {:noreply, %{st | training: :running}}
    end
  end

  @impl true
  def handle_cast(:reload, st) do
    slmp = MiniIntent.prepare()
    {:noreply, %{st | state: slmp, last_summary: load_summary()}}
  end

  @impl true
  def handle_info(:_retrain_done, st) do
    slmp = MiniIntent.prepare()
    {:noreply, %{st | state: slmp, training: :idle, last_summary: load_summary()}}
  end

  @impl true
  def handle_info({:_retrain_failed, msg}, st) do
    {:noreply, %{st | training: {:error, msg}}}
  end

  defp load_summary() do
    path = Path.join(:code.priv_dir(:elixir_ai_core), "mini_intent/training_summary.json")
    with true <- File.exists?(path), {:ok, bin} <- File.read(path), {:ok, json} <- Jason.decode(bin), do: json
  end
end

