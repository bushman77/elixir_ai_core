# lib/core/speech_act.ex
defmodule Core.SpeechAct do
  @moduledoc "Detects speech act and question subtype."

  @wh ~w(how what why when where which who whom whose)
  @aux ~w(do does did can could should would will is are am was were)

  @spec annotate(String.t()) :: {:question | :statement | :command | :fragment | :exclamation, atom() | nil}
  def annotate(sentence) when is_binary(sentence) do
    s = String.trim(sentence)
    d = String.downcase(s)

    cond do
      d =~ ~r/^\s*how\s+to\s+\S/ ->
        {:question, :elliptical}

      starts_with_any?(d, @wh) ->
        {:question, :wh}

      String.ends_with?(d, "?") or starts_with_any?(d, @aux) ->
        {:question, :polar}

      d == "" ->
        {:fragment, nil}

      String.ends_with?(d, "!") ->
        {:exclamation, nil}

      true ->
        {:statement, nil}
    end
  end

  defp starts_with_any?(s, list),
    do: Enum.any?(list, fn w -> String.starts_with?(s, w <> " ") end)
end

