# lib/core/procedure_request.ex
defmodule Core.ProcedureRequest do
  @moduledoc "Heuristics to extract the asked-for procedure from 'how' questions."

  @pronouns ~w(i we you one someone people us me our your their his her)
  @aux_modals ~w(do does did can could should would will to)
  @junk MapSet.new(@pronouns ++ @aux_modals)
  @stop_how ~w(long much many far old often soon late close)

  @spec extract(String.t()) :: {:ok, String.t()} | :nomatch
  def extract(sentence) when is_binary(sentence) do
    s = sentence |> String.trim()
    d = String.downcase(s)

    cond do
      not String.starts_with?(d, "how ") ->
        :nomatch

      starts_with_stop_how?(d) ->
        :nomatch

      true ->
        case from_regex(d) do
          {:ok, task} -> {:ok, normalize(task)}
          :error -> :nomatch
        end
    end
  end

  defp starts_with_stop_how?(<<"how ", rest::binary>>),
    do: Enum.any?(@stop_how, &String.starts_with?(rest, &1 <> " "))

  # Cover common surfaces: "how to X", "how do/does... X"
  defp from_regex(d) do
    cond do
      Regex.match?(~r/^how\s+to\s+(?<task>.+)$/, d) ->
        %{"task" => t} = Regex.named_captures(~r/^how\s+to\s+(?<task>.+)$/, d)
        {:ok, t}

      Regex.match?(~r/^how\s+(do|does|did|can|could|should|would|will)\s+(?<subj>\w+)?\s*(?<task>.+)$/, d) ->
        %{"task" => t} =
          Regex.named_captures(~r/^how\s+(do|does|did|can|could|should|would|will)\s+(?<subj>\w+)?\s*(?<task>.+)$/, d)
        {:ok, t}

      true ->
        :error
    end
  end

  defp normalize(task) do
    task
    |> String.trim()
    |> String.split()
    |> Enum.reject(&MapSet.member?(@junk, &1))
    |> Enum.join(" ")
    |> String.trim_trailing("?")
  end
end

