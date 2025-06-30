defmodule SubstanceEffect do
  def effect(:meth), do: %{dopamine: 1.8, serotonin: -0.5}
  def effect(:alcohol), do: %{dopamine: 0.2, serotonin: -0.6}
  def effect(:cannabis), do: %{dopamine: 0.5, serotonin: 0.3}
end
