defmodule PersistantStorageTest do
  use ExUnit.Case
  doctest GlobalId

  test "that server can read when no last_timestamp.dat is present at the start" do
    _ = File.rm("last_timestamp.dat")
    PersistantStorage.start_link()
    assert 0 === PersistantStorage.load_timestamp()
  end

  test "that server can write when no last_timestamp.dat is present at the start" do
    _ = File.rm("last_timestamp.dat")
    PersistantStorage.start_link()
    ts = Enum.random(0..9999)
    assert :ok === PersistantStorage.save_timestamp(ts)
    assert ts === PersistantStorage.load_timestamp()
  end
end
