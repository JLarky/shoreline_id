defmodule GlobalIdTest do
  use ExUnit.Case
  doctest GlobalId

  test "gets static id" do
    assert GlobalId.get_id() == 1025
  end
end
