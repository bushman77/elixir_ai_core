defmodule BrainNetwork do
  alias BrainCell
  alias SubstanceEffect

  def apply_substance(cells, substance) do
    delta = SubstanceEffect.effect(substance)
    Enum.map(cells, &BrainCell.apply_chemical_change(&1, delta))
  end
end
