defmodule Conman.MessageQueue do
  use GenServer
  require Logger

  @lock_expire_timeout 15000

  defstruct priority_queue: [],
            message_list: %{},
            lock_expire_timeout: @lock_expire_timeout,
            locked_ids: [],
            total_count: 0

  # API Functions

  @doc """
  Starts up the message queue with a link to the process that started it
  """
  def start_link() do
    GenServer.start_link(__MODULE__, @lock_expire_timeout, [name: __MODULE__])
  end

  @doc """
  Stops the message queue. All data in it is lost.
  """
  def stop() do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Pushes the message onto the queue named by the id
  """
  def push(id, message) do
    GenServer.cast(__MODULE__, {:push, id, message})
  end

  @doc """
  Pops all messages for a given connection off the queue. Order is determined by
  insertion order.
  Locks the connection so that no other pop will get messages for that connection
  until it is unlocked.
  """
  def pop() do
    GenServer.call(__MODULE__, :pop)
  end

  @doc """
  Unlocks a locked connection.
  """
  def unlock(id, locked_at) do
    GenServer.cast(__MODULE__, {:unlock, id, locked_at})
  end

  @doc """
  Counts the number of messages that have passed through this queue
  """
  def count() do
    GenServer.call(__MODULE__, :count)
  end

  @doc """
  Counts the number of connections that are currently locked
  """
  def locked_count() do
    GenServer.call(__MODULE__, :locked_count)
  end

  def clear() do
    GenServer.call(__MODULE__, :clear)
  end

  #### GenServer callbacks

  @doc """
  Initialize the message_queue.

  Starts up a timer that runs every lock_expire_timeout seconds that checks if a
  lock is too old, and expires it automatically.
  """
  def init(lock_expire_timeout) do
    Logger.debug "Starting message queue!"
    :timer.send_interval(lock_expire_timeout, :expire_locks)

    { :ok, %Conman.MessageQueue{lock_expire_timeout: lock_expire_timeout} }
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %Conman.MessageQueue{lock_expire_timeout: state.lock_expire_timeout} }
  end

  @doc """
  Returns nothing when the priority queue is empty.
  """
  def handle_call(:pop, _from, state=%Conman.MessageQueue{priority_queue: []}) do
    { :reply, nil, state }
  end

  @doc """
  Pops a set of messages for one connection off the queue.
  """
  def handle_call(:pop, _from, state) do
    [ id | pqueue ] = state.priority_queue
    locked_ids = [ id | state.locked_ids ]
    locked_pack = Conman.MessagePack.lock(state.message_list[id])
    { :reply,
      locked_pack,
      %Conman.MessageQueue{ state | priority_queue: pqueue,
                                    locked_ids: locked_ids,
                                    message_list: %{ state.message_list | id => locked_pack } }
    }
  end

  @doc """
  Get the total count of messages that have passed through this queue
  """
  def handle_call(:count, _from, state) do
    { :reply, state.total_count, state }
  end

  @doc """
  Get the count of currently locked connections
  """
  def handle_call(:locked_count, _from, state) do
    { :reply, length(state.locked_ids), state }
  end

  @doc """
  Debugging only-- return the current state
  """
  def handle_call(:get_state, _from, state) do
    { :reply, state, state }
  end

  @doc """
  Unlock a connection. The ID and locked_at timestamp must match for this to
  work. This is done asynchronously only because there's no reason to wait around
  for it to work.
  """
  def handle_cast({:unlock, id, locked_at}, state) do
    Logger.debug "MessageQueue#handle_cast({unlock, #{id}, #{locked_at}}, state)"
    Logger.debug :io_lib.format("state: ~p~n", [state])
    { :ok, state } = unlock_queue(state, id, locked_at, state.message_list[id])

    { :noreply, state }
  end

  @doc """
  Push a message onto the queue for a connection.

  If this is the first message for that connection, then add it to the priority
  queue as well. If not, then it either is already in the priority queue, or else
  someone has locked it, and we should wait until they unlock it to put it back
  on the queue.
  """
  def handle_cast({:push, id, message}, state) do
    Logger.debug :io_lib.format('pushing ~p onto ~p~n', [message.payload, id])
    pqueue = if Map.has_key?(state.message_list, id) do
               state.priority_queue
             else
               Enum.concat(state.priority_queue, [id])
             end

    message_pack = Map.get(state.message_list, id, %Conman.MessagePack{id: id})
    messages = Enum.concat(message_pack.messages, [message])
    updated_message_pack = %Conman.MessagePack{ message_pack | messages: messages }

    { :noreply,
      %Conman.MessageQueue{ state | total_count: state.total_count + 1,
                                    priority_queue: pqueue,
                                    message_list: Map.put(state.message_list, id, updated_message_pack) }
    }
  end

  @doc """
  Handle a message to expire all overdue locks
  """
  def handle_info(:expire_locks, state) do
    { :noreply, expire_locks(state.locked_ids, state) }
  end

  @doc """
  gen_server callback to clean up anything that needs it on shutdown
  return value is ignored.
  """
  def terminate(_reason, _state) do
    :ok
  end

  @doc """
  gen_server callback to update the state when code changes.
  Nothing to do (yet) here.
  """
  def code_change(_old, state, _extra) do
    { :ok, state }
  end

  ################################################
  ### utility functions

  # unlock the queue-- this version only applies when the locked_at timestamps
  # match. Unlock the message pack, and put it back into the priority queue if
  # there are any messages left
  defp unlock_queue(state, id, locked_at, message_pack=%Conman.MessagePack{locked_at: pack_locked_at}) when locked_at == pack_locked_at do
    Logger.debug("Locked_at timestamps match for #{id}!")
    { message_list, pqueue } =
      if message_pack.message_count == length(message_pack.messages) do
        { Map.delete(state.message_list, message_pack.id), state.priority_queue }
      else
        { Map.put(state.message_list, message_pack.id, Conman.MessagePack.unlock(message_pack)),
          Enum.concat(state.priority_queue, [message_pack.id]) }
      end

    { :ok, %Conman.MessageQueue{ state | message_list: message_list,
                                         priority_queue: pqueue,
                                         locked_ids: List.delete(state.locked_ids, id) } }
  end

  # unlock the queue-- when timestamps do not match, just don't do anything
  defp unlock_queue(state, id, locked_at, message_pack) do
    Logger.debug("Locked_at timestamps don't match for #{id}: trying #{locked_at}, found #{message_pack.locked_at}")
    { :ok, state }
  end

  # expire locks -- when there's something in the list, expire it
  defp expire_locks([conn_id | rest], state) do
    case Map.get(state.message_list, conn_id) do
      nil          -> expire_locks(rest, state)
      message_pack ->
        new_state = expire_lock(message_pack, :erlang.system_time(:nano_seconds), state)
        expire_locks(rest, new_state)
    end
  end

  # expire locks-- just return state when we're done
  defp expire_locks([], state) do
    state
  end

  # utility to expire a lock that's too old
  # -- remove it from the list of locked connection ids
  # -- put an expired version of the message pack back in the message list
  # -- append it to the priority queue.
  #
  # returns a new state
  defp expire_lock(message_pack=%Conman.MessagePack{locked_at: locked_at}, now,
                   state=%Conman.MessageQueue{lock_expire_timeout: timeout}) when now - locked_at > timeout * 1000000 do
    Logger.debug "expire_lock for #{message_pack.id} because it's too old"
    message_list = Map.put(state.message_list, message_pack.id, Conman.MessagePack.expire_lock(message_pack))

    %Conman.MessageQueue{ state | locked_ids: List.delete(state.locked_ids, message_pack.id),
                                  message_list: message_list,
                                  priority_queue: Enum.concat(state.priority_queue, [message_pack.id]) }
  end

  # utility to expire a lock that's not too old
  # -- don't do anything, just return state
  defp expire_lock(message_pack, _now, state) do
    Logger.debug "expire_lock(#{message_pack.id},...), ignoring because it's not old enough"
    state
  end
end
