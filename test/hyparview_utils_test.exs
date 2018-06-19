defmodule Hyparview.UtilsTest do
  use ExUnit.Case

  test "random_delay/1" do
    assert Hyparview.Utils.random_delay(1000) in Range.new(1000, 1001 * 1001)
  end

  test "choose_node/1" do
    expects = MapSet.new([:a, :b, :c])
    node = Hyparview.Utils.choose_node(expects)

    expects
    |> MapSet.member?(node)
    |> assert()
  end
end
