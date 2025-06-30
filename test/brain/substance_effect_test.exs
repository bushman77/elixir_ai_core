defmodule BrainCell.SubstanceEffectTest do
  use ExUnit.Case

  alias ElixirAiCore.Core
  alias BrainCell
  # Assuming this is your network layer (not Brain.Network)
  alias BrainNetwork

  setup do
    cells = [
      %BrainCell{id: :a},
      %BrainCell{id: :b},
      %BrainCell{id: :c}
    ]

    %{cells: cells}
  end

  test "applying meth overstimulates most cells", %{cells: cells} do
    updated = BrainNetwork.apply_substance(cells, :meth)
    assert Enum.all?(updated, fn c -> c.status == :overstimulated end)
  end

  test "applying alcohol suppresses cells", %{cells: cells} do
    updated = BrainNetwork.apply_substance(cells, :alcohol)
    assert Enum.all?(updated, fn c -> c.status in [:suppressed, :inactive] end)
  end

  test "cannabis mildly enhances mood", %{cells: cells} do
    updated = BrainNetwork.apply_substance(cells, :cannabis)
    assert Enum.all?(updated, fn c -> c.serotonin > 1.0 end)
  end

  test "withdrawal triggers after substance delay" do
    now = 1000

    # Start with a fresh cell
    cell = %BrainCell{id: :a, serotonin: 1.0, dopamine: 1.0}

    # Apply alcohol dose at `now`
    dosed =
      BrainCell.apply_chemical_change(cell, %{dopamine: -0.1, serotonin: -0.7}, :alcohol, now)

    assert dosed.status == :suppressed
    # 5 minutes later — not enough for withdrawal
    after_5 = BrainCell.Withdrawal.check_and_apply(dosed, now + 5 * 60)

    assert after_5.status == :suppressed
    assert_in_delta after_5.serotonin, 0.3, 0.001
    assert_in_delta after_5.dopamine, 0.9, 0.001

    # 8 minutes later — withdrawal kicks in
    after_8 = BrainCell.Withdrawal.check_and_apply(dosed, now + 8 * 60)
    assert after_8.status == :withdrawal

    # Serotonin and dopamine drop further
    assert after_8.serotonin < 0.7
    assert after_8.dopamine < 0.9
  end
end
