defmodule GlobalId do
  use GenServer

  @moduledoc """
  GlobalId module contains an implementation of a guaranteed globally unique id system.
  """

  @doc """
  Please implement the following function.
  64 bit non negative integer output
  """
  @spec get_id() :: non_neg_integer
  def get_id() do
    GenServer.call(__MODULE__, :get_id)
  end

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
    {:ok, %{args | last_ts: ts}}
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
  """
  @spec timestamp() :: non_neg_integer
  def timestamp do
    # :erlang.system_time(:millisecond)
    1_584_304_105_123
  end
end
