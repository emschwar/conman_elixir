defmodule Conman.ConnectionMap do
  use GenServer

  defstruct connection_map: %{},
            alias_map: %{}

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def add(connection_id, connection) do
    GenServer.cast(__MODULE__, {:add, connection_id, connection})
  end

  def count() do
    GenServer.call(__MODULE__, :count)
  end

  def ips() do
    GenServer.call(__MODULE__, :get_ips)
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def remove(id) do
    GenServer.cast(__MODULE__, {:remove, id})
  end

  def clear() do
    GenServer.call(__MODULE__, :clear)
  end

  ### GenServer callbacks
  def init([]) do
    { :ok, %Conman.ConnectionMap{} }
  end

  def handle_call(:clear, _from, _state) do
    { :reply, :ok, %Conman.ConnectionMap{} }
  end

  def handle_call(:count, _from, state) do
    { :reply, Map.size(state.connection_map), state }
  end

  def handle_call(:get_ips, _from, state) do
    ips = Enum.map(Map.values(state.connection_map), fn(conn) -> Conman.Socket.get_ip(conn) end)

    { :reply, ips, state }
  end

  def handle_call({:get, id}, _from, state) do
    { :reply, Map.get(state.connection_map, id, :nothing), state }
  end

  def handle_call(:get_state, _from, state) do
    { :reply, state, state }
  end

  def handle_cast({:add, id, connection}, state) do
    connection_map = Map.put(state.connection_map, id, connection)
    { :noreply, %Conman.ConnectionMap{ state | connection_map: connection_map } }
  end

  def handle_cast({:remove, id}, state) do
    connection_map = Map.delete(state.connection_map, id)
    { :noreply, %Conman.ConnectionMap{ state | connection_map: connection_map } }
  end
end
