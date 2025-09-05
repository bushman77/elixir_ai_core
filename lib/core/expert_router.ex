defmodule Core.ExpertRouter do
  @moduledoc """
  Chooses decode settings and mood adapter based on intent+mood.
  """
  def route(intent, mood) do
    exp = Application.fetch_env!(:elixir_ai_core, :experts)
    moods = Application.fetch_env!(:elixir_ai_core, :moods)
    decode = Map.get(exp, intent, Map.fetch!(exp, :general))[:decode]
    mood_id = Map.get(moods, mood, :mood_grumpy)
    %{decode: decode, mood_id: mood_id}
  end
end
