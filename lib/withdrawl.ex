defmodule BrainCell.Withdrawal do
  require Logger
  alias ElixirAiCore.Core
  alias BrainCell

  @withdrawal_effects %{
    alcohol: %{dopamine: -0.2, serotonin: -0.1},
    meth: %{dopamine: -0.4, serotonin: -0.3},
    cannabis: %{dopamine: -0.2, serotonin: -0.2}
  }

  @doc "Checks if enough time has passed to trigger withdrawal effects."
  def check_and_apply(%BrainCell{} = cell, current_time) do
    case {cell.last_dose_at, cell.last_substance} do
      {nil, _} ->
        cell

      {last_time, substance} ->
        if current_time - last_time >= withdrawal_delay(substance) do
          apply_withdrawal_effect(cell, substance)
        else
          cell
        end
    end
  end

  defp withdrawal_delay(:alcohol), do: 7 * 60
  defp withdrawal_delay(:cannabis), do: 24 * 60
  defp withdrawal_delay(:meth), do: 6 * 60
  # default fallback
  defp withdrawal_delay(_), do: 10 * 60

  defp apply_withdrawal_effect(%BrainCell{last_substance: nil} = cell, _substance) do
    Logger.warn("Withdrawal attempted with no substance; skipping.")
    cell
  end

  defp apply_withdrawal_effect(%BrainCell{} = cell, substance) do
    deltas = Map.get(@withdrawal_effects, substance, %{dopamine: -0.2, serotonin: -0.1})

    new_ser = Core.clamp(cell.serotonin + deltas.serotonin, 0.0, 2.0)
    new_dop = Core.clamp(cell.dopamine + deltas.dopamine, 0.0, 2.0)

    %BrainCell{
      cell
      | serotonin: new_ser,
        dopamine: new_dop,
        status: :withdrawal
    }
  end
end
