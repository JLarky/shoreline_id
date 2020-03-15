defmodule GlobalIdTest do
  use ExUnit.Case
  doctest GlobalId

  test "calling multiple times increases counter" do
    {:ok, _pid} = GlobalId.start_link([])
    assert GlobalId.get_id() == 6_645_053_045_335_916_544
    assert GlobalId.get_id() == 6_645_053_045_335_916_545
  end

  test "BUG: calling get_id too many times in one millisecond will overflow counter and id will duplicate" do
    {:ok, _pid} = GlobalId.start_link([])
    id = GlobalId.get_id()
    for i <- 1..2047, do: GlobalId.get_id()
    assert GlobalId.get_id() !== id
  end

  test "test id 0" do
    assert GlobalId.format_id(0, 0, 0) == 0
  end

  test "test max id" do
    assert GlobalId.format_id(4_398_046_511_103, 2047, 2047) + 1 == :math.pow(2, 64)
  end
end
