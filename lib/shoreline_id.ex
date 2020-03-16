defmodule GlobalId do
  use GenServer

  @moduledoc """
  GlobalId module contains an implementation of a guaranteed globally unique id system.

  ## Example

      iex> {:ok, _} = GlobalId.start_link()
      iex> GlobalId.get_id()
      6645053045335916544
      iex> GlobalId.get_id()
      6645053045335916545

  Generating 10,000 unique ids

      iex> {:ok, _} = GlobalId.start_link()
      iex> ids = for _ <- 1..10_000, do: GlobalId.get_id()
      iex> length(Enum.uniq(ids))
      10_000
  """

  @doc """
  `get_id` doesn't take any parameters and instead it's state is stored in GenServer. Returns globally unique 64 bit non negative integer.
  """
  @spec get_id() :: non_neg_integer
  def get_id() do
    GenServer.call(__MODULE__, :get_id)
  end

  @doc """
  `format_id` is heart of `get_id` and formats unique number. Middle 11 bits are unique for each node,
  so given that node_id is not reused for different machine no two ids from different nodes is going
  to be the same.

  To ensure that particular node doesn't generate the same id twice we need to perform three tasks,
  main is to use epoch time as first 42 bits of our integer. To combat issue of generating multiple
  ids during the same epoch time, we keep track of counter and increment it for each call. Third is
  to store epoch time in persistent storage, to ensure that we are not re-using any timestamps on
  the same node.

  Our solution should work for case when 100,000 ids need to be generated per second, since we can
  only use 11 bits for counter that might cause counter to overflow over 2047 at which point we can
  simply sleep for 1ms or advance time for 1ms manually. In case of peek load that might mean that
  timestamp portion of id is going to have time that is bigger than system current time. But
  100,000 requests require only 49 milliseconds to catch up to real timestamp and we have budget
  of 1000 milliseconds, and sutainable load of 1000 requests per second should never overflow the
  counter of 2047.

  Order of bits is selected so that sorting ids generated from one machine will be equivalent to
  sorting by time, and two ids generated on one node right after each other would most likelly be
  different by just 1, which is easier to spot visually. Alternativelly one can choose order
  (ts, counter, node) for which sorting by time would most probably be true even between nodes,
  but I don't believe that it's always feasable to have whole cluster's time be so accurate, as
  NTP accuracy is usually measured in milliseconds, and even then counter value will depend on
  how busy particular node is.
  """
  @spec format_id(integer, integer, integer) :: non_neg_integer
  def format_id(ts, node, counter) do
    # if our code is going to run no later than May 15, 2109 we can store timestamp as 42 bit unsigned integer
    # if ts > 4_398_046_511_103 do
    #   # <<4398046511103::42>>
    #   throw(:too_late)
    # end

    # unfotrunatelly since node_id can be both 0 and 1024 at the same time we need at least 11 bits
    # if node > 2047 do
    #   # <<2047::11>>
    #   throw(:too_many_nodes)
    # end

    # we only have 11 bits left for counter
    # if counter > 2047 do
    #   # <<2047::11>>
    #   throw(:too_many_counts)
    # end

    <<id::64>> = <<ts::42, node::11, counter::11>>
    id
  end

  @doc false
  def inspect_id(id) do
    <<ts::42, node::11, counter::11>> = <<id::64>>

    {ts, node, counter}
  end

  def start_link() do
    GenServer.start_link(
      __MODULE__,
      %{node_id: node_id(), counter: 0, last_ts: 0},
      name: __MODULE__
    )
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
  def init(args) do
    case PersistantStorage.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    ts = PersistantStorage.load_timestamp()
    # we might perform check here that timestamp is reasonably close to current time, to notify
    # about possible issues with system time
    {:ok, %{args | last_ts: ts + 1}}
  end

  @impl true
  def handle_call(:get_id, _from, %{node_id: node, counter: counter, last_ts: last_ts} = state) do
    # `last_ts` could be in future compared to `ts` for two main reasons:
    # 1. clock could be out of sync, for example after restart it shows wrong time compared to last run
    # 2. we are getting too many requests per second so our `counter` is overflown and we had to increment time instead
    ts = max(timestamp(), last_ts)

    # we are saving ts to disk every time `ts` is advancing
    {ts, counter} =
      cond do
        # go to next ts if counter has overflown
        counter >= 2047 ->
          PersistantStorage.save_timestamp(ts + 1)
          {ts + 1, 0}

        # new ts resets counter
        ts > last_ts ->
          PersistantStorage.save_timestamp(ts)
          {ts, 0}

        # calls within the same ts increment counter
        true ->
          {ts, counter + 1}
      end

    id = format_id(ts, node, counter)
    {:reply, id, %{state | counter: counter, last_ts: ts}}
  end

  #
  # You are given the following helper functions
  # Presume they are implemented - there is no need to implement them.
  #

  @doc """
  Returns your node id as an integer.
  It will be greater than or equal to 0 and less than or equal to 1024.
  It is guaranteed to be globally unique.
  """
  @spec node_id() :: non_neg_integer
  def node_id do
    1024
  end

  @doc """
  Returns timestamp since the epoch in milliseconds.

  You can either do `:ok = :file.sync(fd)` or `:erlang.system_time(:millisecond)` to generate a lot
  of ids fast. We need `file:sync` so that our tests will not mess up with each other, but in real
  system crash that will cause file write operation to fail is not going to be fixed in short enough
  time so that lost write data is going to make a difference. So we can skip `sync` all together.

  Alternative approach is to do sync less often, for example each time `save_timestamp` is called we
  store `ts + 100` on disk and do no sync writes until we get new ts that is bigger than what is
  already stored in file. This way we can ensure than after recovery there will be no timestamps
  reused instead of just hoping for slow recovery. Even if recovery is extremely fast there will be
  no id reuse, but might be some time where timestamp in id is running ahead of system time (by
  100ms in this example).
  """
  @spec timestamp() :: non_neg_integer
  def timestamp do
    # :erlang.system_time(:millisecond)
    1_584_304_105_123
  end
end
