defmodule Conman.OutgoingQueue do
  use GenServer
  require Logger

  defstruct messages: [],
            sending: false,
            total_count: 0

  @doc """
  starts up the outgoing queue gen_server
  """
  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @doc """
  Stop the outgoing queue gen_server
  """
  def stop() do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Send message to the connection named id
  """
  def send_message(id, message) do
    Logger.debug("Sending message: #{List.flatten :io_lib.format("~p", [message])}")
    GenServer.cast(__MODULE__, {:send, id, message})
  end

  @doc """
  Return the total number of outgoing messages we've sent
  """
  def total_count() do
    GenServer.call(__MODULE__, :total_count)
  end

  @doc """
  Return the number of outgoing messages we have stored but not yet sent
  """
  def stored_count() do
    GenServer.call(__MODULE__, :stored_count)
  end

  ### GenServer callbacks
  @doc """
  Initialize the outgoing queue gen_server with an empty queue state
  """
  def init([]) do
    { :ok, %Conman.OutgoingQueue{} }
  end

  @doc """
  Get the total count from the state
  """
  def handle_call(:total_count, _from, state) do
    { :reply, state.total_count, state }
  end

  @doc """
  Get the stored count from the stored messages in the state
  """
  def handle_call(:stored_count, _from, state) do
    { :reply, length(state.messages), state }
  end

  @doc """
  Append messages to the queue when no messages are being sent
  """
  def handle_cast({:send, id, payload}, state=%Conman.OutgoingQueue{sending: false}) do
    # set an immediate timeout to start sending messages asynchronously
    Process.send_after(self(), :send_messages, 0)
    # append the message to the outgoing queue and return
    { :noreply,
      %Conman.OutgoingQueue{ state | total_count: state.total_count + 1,
                                     messages: append_message(id, payload, state.messages) }
    }
  end

  @doc """
  Append messages to the queue when messages are already being sent
  """
  def handle_cast({:send, id, payload}, state=%Conman.OutgoingQueue{sending: true}) do
    # append the message to the outgoing queue and return
    { :noreply,
      %Conman.OutgoingQueue{ state | total_count: state.total_count + 1,
                                     messages: append_message(id, payload, state.messages) }
    }
  end

  @doc """
  send messages from the queue
  """
  def handle_info(:send_messages, state=%Conman.OutgoingQueue{messages: [message|rest]}) do
    dispatch_message(message)

    Process.send_after(self(), :send_messages, 0)
    { :noreply, %Conman.OutgoingQueue{state | messages: rest} }
  end

  @doc """
  Send messages from an empty queue
  """
  def handle_info(:send_messages, state=%Conman.OutgoingQueue{messages: []}) do
    { :noreply, %Conman.OutgoingQueue{ state | sending: false } }
  end

  defp dispatch_message(message) do
    case Conman.ConnectionMap.get(message.sender) do
      :nothing   -> :nothing
      connection -> send connection, { :send, message.payload }
    end
  end

  defp append_message(id, payload, messages) do
    Enum.concat(messages, [%Conman.Message{sender: id, payload: payload}])
  end
end
