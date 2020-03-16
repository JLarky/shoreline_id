defmodule GlobalIdTest do
  use ExUnit.Case
  doctest GlobalId

  test "calling multiple times increases counter" do
    {:ok, _pid} = GlobalId.start_link()
    assert GlobalId.get_id() == 6_645_053_045_335_916_544
    assert GlobalId.get_id() == 6_645_053_045_335_916_545
  end

  test "calling get_id too many times in one millisecond will overflow counter so ts will increase instead" do
    {:ok, _pid} = GlobalId.start_link()
    id = GlobalId.get_id()
    for _ <- 1..2047, do: GlobalId.get_id()
    assert GlobalId.get_id() !== id
  end

  test "BUG: counter overflow is not safe on GenServer restart" do
    {:ok, _pid} = GlobalId.start_link()
    id = GlobalId.get_id()
    for _ <- 1..2047, do: GlobalId.get_id()
    _overflow_id = GlobalId.get_id()
    GenServer.stop(GlobalId)
    {:ok, _pid} = GlobalId.start_link()
    assert GlobalId.get_id() !== id
  end

  test "test id 0" do
    assert GlobalId.format_id(0, 0, 0) == 0
  end

  test "test max id" do
    assert GlobalId.format_id(4_398_046_511_103, 2047, 2047) + 1 == :math.pow(2, 64)
  end
end
