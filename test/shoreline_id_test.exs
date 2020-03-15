defmodule GlobalIdTest do
  use ExUnit.Case
  doctest GlobalId

  test "gets static id" do
    assert GlobalId.get_id() == 6_645_053_045_335_916_544
  end

  test "test id 0" do
    assert GlobalId.format_id(0, 0, 0) == 0
  end

  test "test max id" do
    assert GlobalId.format_id(4_398_046_511_103, 2047, 2047) + 1 == :math.pow(2, 64)
  end
end
