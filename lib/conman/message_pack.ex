defmodule Conman.MessagePack do
  defstruct id: nil,
            locked_at: nil,
            message_count: 0,
            messages: []

  @doc """
  Locks the message pack.

  Sets locked_at to now, and message_count to the current message length,
  so that any messages that come in while it's locked can be processed later.
  """
  def lock(message_pack) do
    %Conman.MessagePack{ message_pack |
                         locked_at: :erlang.system_time(:nano_seconds),
                         message_count: length(message_pack.messages) }
  end

  @doc """
  Reset message count to 0 and locked_at to nil, indicating that this pack is no
  longer locked.
  """
  def expire_lock(message_pack) do
    %Conman.MessagePack{ message_pack | message_count: 0, locked_at: nil }
  end

  @doc """
  Like expire_lock, but since the unlock is being called manually, drop the
  messages that were processed while it was locked.
  """
  def unlock(message_pack) do
    messages = Enum.drop(message_pack.messages, message_pack.message_count)
    %Conman.MessagePack{ expire_lock(message_pack) | messages: messages}
  end

end
