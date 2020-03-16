defmodule GlobalIdTest do
  use ExUnit.Case
  doctest GlobalId

  setup do
    PersistantStorage.start_link()
    PersistantStorage.save_timestamp(0)
    :ok
  end

  test "calling multiple times increases counter" do
    {:ok, _pid} = GlobalId.start_link()
    assert GlobalId.get_id() == 6_645_053_045_335_916_544
    assert GlobalId.get_id() == 6_645_053_045_335_916_545
  end

  test "calling get_id too many times in one millisecond will overflow counter so ts will increase instead" do
    {:ok, _pid} = GlobalId.start_link()
    id = GlobalId.get_id()
    for _ <- 1..2047, do: GlobalId.get_id()
    assert {1_584_304_105_123, 1024, 0} === GlobalId.inspect_id(id)
    overflow_id = GlobalId.get_id()
    assert overflow_id !== id
    assert {1_584_304_105_124, 1024, 0} === GlobalId.inspect_id(overflow_id)
    overflow_id = GlobalId.get_id()
    assert {1_584_304_105_124, 1024, 1} === GlobalId.inspect_id(overflow_id)
    overflow_id = GlobalId.get_id()
    assert {1_584_304_105_124, 1024, 2} === GlobalId.inspect_id(overflow_id)
  end

  test "that counter overflow is safe on GenServer restart" do
    {:ok, _pid} = GlobalId.start_link()
    id = GlobalId.get_id()
    for _ <- 1..2047, do: GlobalId.get_id()
    _overflow_id = GlobalId.get_id()
    GenServer.stop(GlobalId)
    {:ok, _pid} = GlobalId.start_link()
    assert GlobalId.get_id() !== id
  end

  test "that on GenServer restart proper last_ts is stored" do
    {:ok, _pid} = GlobalId.start_link()
    id = GlobalId.get_id()
    for _ <- 1..2047, do: GlobalId.get_id()
    assert {1_584_304_105_123, 1024, 0} === GlobalId.inspect_id(id)
    overflow_id = GlobalId.get_id()
    assert {1_584_304_105_124, 1024, 0} === GlobalId.inspect_id(overflow_id)
    overflow_id2 = GlobalId.get_id()
    assert {1_584_304_105_124, 1024, 1} === GlobalId.inspect_id(overflow_id2)
    GenServer.stop(GlobalId)
    {:ok, _pid} = GlobalId.start_link()
    new_id = GlobalId.get_id()
    assert new_id !== id
    assert new_id !== overflow_id
    assert new_id !== overflow_id2
    assert {1_584_304_105_125, 1024, 1} === GlobalId.inspect_id(new_id)
  end

  test "test id 0" do
    assert GlobalId.format_id(0, 0, 0) == 0
  end

  test "test max id" do
    assert GlobalId.format_id(4_398_046_511_103, 2047, 2047) + 1 == :math.pow(2, 64)
  end

  test "generate a lot of ids for 1 second (disable it if running with real implementation of GlobalId.timestamp)" do
    {:ok, _} = GlobalId.start_link()
    ids = for _ <- 1..250_000, do: GlobalId.get_id()
    assert length(Enum.uniq(ids)) === 250_000
  end
end
