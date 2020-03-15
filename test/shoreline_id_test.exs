defmodule GlobalIdTest do
  use ExUnit.Case
  doctest GlobalId

  test "greets the world" do
    assert GlobalId.hello() == :world
  end
end
