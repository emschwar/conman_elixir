defmodule Conman.Socket do
  use GenServer
  require Logger

  defstruct ref: nil,
            socket: nil,
            transport: nil,
            handler: nil,
            connection_id: nil,
            initialized: false,
            partial_input: <<>>

  @behaviour :ranch_protocol

  @socket_timeout 60000

  @doc """
  Starts the gen_server from a Ranch callback.
  """
  def start_link(ref, socket, transport, opts) do
    Logger.debug("Conman.socket.start_link!")
    GenServer.start_link(__MODULE__, [ref, socket, transport, opts], [])
  end

  @doc """
  Given a pid of a socket, return the socket's remote IP address
  """
  def get_ip(socket_pid) do
    GenServer.call(socket_pid, :get_ip)
  end

  ## gen server callbacks

  @doc """
  Initializes the socket connection. Due to a quirk of how ranch works, we cannot
  actually accept the connection here; instead, we'll timeout, and let our
  handle_info clause take care of it.
  """
  def init([ref, socket, transport, opts]) do
    Logger.debug("Conman.socket.start_link!")
    handler = Keyword.get(opts, :connection_handler)

    # return timeout of 0 to immediately timeout
    { :ok, %Conman.Socket{ref: ref, socket: socket, transport: transport, handler: handler}, 0 }
  end

  def handle_call(:get_state, _, state) do
    { :reply, state, state }
  end

  @doc """
  Get the IP address for this connection
  """
  def handle_call(:get_ip, _from, state=%Conman.Socket{transport: transport, socket: socket}) do
    { :ok, {ip, _port}} = transport.peername(socket)

    { :reply, :inet.ntoa(ip), state, @socket_timeout }
  end

  @doc """
  Handles the very first timeout, from the init. Note that we are specifying
  initialized: false in the header here-- this means that this version of
  handle_info will only run when initialized is false.
  """
  def handle_info(:timeout, state=%Conman.Socket{initialized: false}) do
    Logger.debug("Conman.socket.handle_info(:timeout, initialized: false)!")
    connection_id = UUID.uuid4()
    :ok = setup_ranch_socket(state)

    IO.puts "initial timeout: accepted ranch socket connection for id #{connection_id}"

    Conman.ConnectionMap.add(connection_id, self())
    send self(), { :send, <<>> }
    send self(), { :send, <<>> }
    :ssl.negotiated_protocol(state.socket)
    { :noreply, %{ state | initialized: true, connection_id: connection_id }, @socket_timeout }
  end

  @doc """
  Handles an actual socket timeout
  """
  def handle_info(:timeout, state=%Conman.Socket{connection_id: conn_id}) do
    Logger.debug("Conman.socket.handle_info(:timeout, initialized: true)!")
    # log the error
    # TODO: use a real logging library
    Logger.info("timeout on connection #{conn_id}")
    { :stop, :shutdown, state }
  end

  @doc """
  Handles an explicitly closed SSL socket
  """
  def handle_info({:ssl_closed, _socket}, state) do
    Logger.info("socket for #{state.connection_id} closed")
    { :stop, :shutdown, state }
  end

  @doc """
  Handles receiving an SSL message
  """
  def handle_info({:ssl, _port, message}, state=%Conman.Socket{socket: socket, transport: transport, connection_id: conn_id}) do
    IO.puts "received encrypted message: #{Base.encode64(message)} on connection: #{conn_id}"
    set_socket_active(transport, socket)
    process_input(message, state)
  end

  @doc """
  Handles receiving an TCP message
  """
  def handle_info({:tcp, _port, message}, state=%Conman.Socket{socket: socket, transport: transport, connection_id: conn_id}) do
    IO.puts "received plaintext message: #{Base.encode64(message)} on connection: #{conn_id}"
    set_socket_active(transport, socket)
    process_input(message, state)
  end

  @doc """
  Send a message back to the other side of the socket
  """
  def handle_info({:send, payload}, state=%Conman.Socket{socket: socket, transport: transport}) do
    Logger.debug("sending #{:io_lib.format("~p", [payload])}")
    transport.send(socket, payload)
    { :noreply, state }
  end

  @doc """
  gen_server terminate callback.

  * Shutdown the socket
  * send a disconnected message
  * remove the connection from the map

  (note: return value is ignored)
  """
  def terminate(_reason, state) do
    state.transport.close(state.socket)
    conn_id = state.connection_id

    Conman.MessageQueue.push(conn_id, Conman.Message.disconnected(conn_id))
    Conman.ConnectionMap.remove(conn_id)
  end

  @doc """
  gen_server code_change callback. Nothing to do here (yet).
  """
  def code_change(_old_vsn, state, _extra) do
    { :ok, state }
  end

  ### application-specific functions

  # Accepts a ranch socket and sets it up to receive data.
  # May NOT be called from init/1!!! This is very bad and will not work!!!
  # The 'correct' thing to do is call this from an immediate timeout set up from
  # init/1
  defp setup_ranch_socket(%Conman.Socket{ref: ref, socket: socket, transport: transport}) do
    :ok = :ranch.accept_ack(ref)
    :ok = set_socket_active(transport, socket)
    :ok
  end

  # Set up the socket to receive data
  defp set_socket_active(transport, socket) do
    :ok = transport.setopts(socket, [{:active, :once}])
    :ok
  end

  # process one message
  defp process_input(input, state=%Conman.Socket{partial_input: partial_input, handler: handler, connection_id: connection_id}) do
    { message, remaining_input } = handler.input_received(partial_input, input)
    Logger.debug("socket listener, post-input received: #{message}, #{remaining_input}")
    case message do
      :nothing -> { :noreply, %{state | partial_input: remaining_input}, @socket_timeout }
      :invalid -> { :stop, :shutdown, state }
      _ ->
        # push the message onto the message queue
        Logger.debug("got a complete message on #{connection_id}!")
        Conman.MessageQueue.push(connection_id, Conman.Message.new(connection_id, message))
        { :noreply, %{state | partial_input: remaining_input}, @socket_timeout }
    end
  end
end
