# lib/core/templates/steps.ex
defmodule Core.Templates.Steps do
  @moduledoc "Renders step-by-step procedures from an :act slot."

  @aliases %{
    "brush my teeth"   => "brush teeth",
    "brush our teeth"  => "brush teeth",
    "brush your teeth" => "brush teeth"
  }

  @recipes %{
    "brush teeth" => [
      "Grab a soft-bristled toothbrush and fluoride toothpaste.",
      "Wet the bristles and apply a pea-sized amount of toothpaste.",
      "Angle the brush ~45° to the gumline; use gentle, small circles.",
      "Spend ~30s per quadrant (≈2 minutes total): outer, inner, chewing surfaces.",
      "Gently brush the tongue and roof of the mouth.",
      "Spit; avoid heavy rinsing so a thin fluoride film remains.",
      "Rinse the brush and let it air-dry. Floss once per day."
    ]
  }

  def for(act) when is_binary(act) do
    key =
      act
      |> String.downcase()
      |> String.replace(~r/\b(my|our|your)\b/, "")
      |> String.trim()
      |> (&Map.get(@aliases, &1, &1)).()

    Map.get(@recipes, key, generic(act))
  end

  def render(act, steps) when is_list(steps) do
    header = "Here’s a simple way to #{headline(act)}:"
    numbered =
      steps
      |> Enum.with_index(1)
      |> Enum.map(fn {s, i} -> "#{i}. #{s}" end)
      |> Enum.join("\n")

    header <> "\n\n" <> numbered
  end

  defp generic(act) do
    [
      "Gather what you need for #{act}.",
      "Prepare the space/tools; remove blockers.",
      "Do the main action in small, controlled steps.",
      "Check the result; repeat or adjust as needed.",
      "Clean up and store tools for next time."
    ]
  end

  defp headline(act) do
    act
    |> String.trim()
    |> String.replace_leading("to ", "")
  end
end

