defmodule Core.Profanity do
  @moduledoc "Lightweight profanity detector."

  @denylist ~w(fuck fucking fucker shit asshole bastard bitch cunt dick prick motherfucker douche retard retarded whore slut)

  # Unicode-safe, non-alnum boundaries
  @strict @denylist
          |> Enum.map(&Regex.escape/1)
          |> Enum.join("|")
          |> then(&Regex.compile!("(?<![[:alnum:]])(?:#{&1})(?![[:alnum:]])", "iu"))

  # Spacing/obfuscation tolerant (e.g., f u c k, f*ck) — enable if desired
  @loose @denylist
         |> Enum.map(fn w ->
           chars = String.graphemes(w) |> Enum.map(&Regex.escape/1) |> Enum.join("[^[:alnum:]]*")
           "(?<![[:alnum:]])#{chars}(?![[:alnum:]])"
         end)
         |> Enum.join("|")
         |> then(&Regex.compile!("(?:#{&1})", "iu"))

  @spec hit?(String.t()) :: boolean
  def hit?(s) when is_binary(s) do
    Regex.match?(@strict, s) or Regex.match?(@loose, s)
  end
  def hit?(_), do: false
end

