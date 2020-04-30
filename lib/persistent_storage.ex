defmodule PersistantStorage do
  use GenServer

  @db_path "last_timestamp.dat"

  @moduledoc """
  PersistantStorage module stores timestamp on disk so we can read it later

  ## Examples

      iex> {:ok, _} = PersistantStorage.start_link()
      iex> PersistantStorage.save_timestamp(123)
      :ok
      iex> PersistantStorage.load_timestamp()
      123
  """

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Reads value from disk, returning `0` if no value was stored
  """
  @spec load_timestamp :: non_neg_integer
  def load_timestamp() do
    GenServer.call(__MODULE__, :load)
  end

  @doc """
  Saves value to disk
  """
  @spec save_timestamp(non_neg_integer) :: :ok
  def save_timestamp(ts) do
    GenServer.call(__MODULE__, {:save, ts})
  end

  @impl true
  @spec init(nil) :: {:ok, map()}
  def init(_) do
    fd = File.open!(@db_path, [:read, :write, :binary])
    {:ok, %{fd: fd}}
  end

  @impl true
  def handle_call(:load, _from, %{fd: fd} = state) do
    ts =
      case :file.pread(fd, 0, 8) do
        {:ok, <<x::64>>} ->
          x

        :eof ->
          0
      end

    {:reply, ts, state}
  end

  @impl true
  def handle_call({:save, ts}, _from, %{fd: fd} = state) do
    :ok = :file.pwrite(fd, 0, <<ts::64>>)
    # see notes about `:file.sync` in `h GlobalId.timestamp`
    :ok = :file.sync(fd)
    {:reply, :ok, state}
  end
end
