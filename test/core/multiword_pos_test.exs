defmodule Core.MultiwordPOSTest do
  use ExUnit.Case, async: true
  alias Core.MultiwordPOS

  test "phrases returns normalized, non-empty list" do
    list = MultiwordPOS.phrases()
    assert is_list(list) and length(list) > 10
    assert Enum.all?(list, &(String.downcase(&1) == &1 and String.trim(&1) == &1))
    assert Enum.uniq(list) == list
  end

  test "lookup: greetings" do
    for p <- ["good morning", "good afternoon", "good evening", "see you later"] do
      assert MultiwordPOS.lookup(p) == :interjection
    end
  end

  test "lookup: thanks/courtesy" do
    assert MultiwordPOS.lookup("thank you") == :interjection
    assert MultiwordPOS.lookup("thanks a lot") == :interjection
    assert MultiwordPOS.lookup("please and thank you") == :particle
  end

  test "lookup: wh starters (exact)" do
    for p <- ["what time", "how many", "how much", "where is", "who are", "when will", "why is"] do
      assert MultiwordPOS.lookup(p) == :wh
    end
  end

  test "lookup handles case + whitespace normalization" do
    assert MultiwordPOS.lookup("  WHAT   TIME  ") == :wh
    assert MultiwordPOS.lookup("   Good   Morning  ") == :interjection
  end

  test "lookup expands contractions (straight and curly apostrophes)" do
    assert MultiwordPOS.lookup("what's the time") == :wh
    assert MultiwordPOS.lookup("what’s the time") == :wh
    assert MultiwordPOS.lookup("Where's the station") == :wh   # via prefix after expansion
  end

  test "prefix match uses word boundary" do
    # Should match because boundary is a space
    assert MultiwordPOS.lookup("where is the station") == :wh
    # Should NOT match because there's no boundary (no space)
    assert MultiwordPOS.lookup("where isthmus located") == nil
  end

  test "lookup: command-ish phrases" do
    for p <- ["open settings", "turn on", "turn off", "log out", "sign in", "sign up"] do
      assert MultiwordPOS.lookup(p) == :verb
    end
  end

  test "unknown phrase returns nil" do
    assert MultiwordPOS.lookup("unknown multiword") == nil
  end
end

