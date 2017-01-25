defmodule Conman.MessageQueueTest do
  use ExUnit.Case

  doctest Conman.MessageQueue

  setup do
    Conman.MessageQueue.clear()

    { :ok, [] }
  end

  test "pushes a message successfully", _context do
    assert Conman.MessageQueue.push(:an_id, %{payload: "A Message"}) == :ok
  end

  test "increments the total count when pushing a message", _context do
    assert Conman.MessageQueue.count() == 0
    Conman.MessageQueue.push(:an_id, %{payload: "A Message"})
    assert Conman.MessageQueue.count() == 1
  end

  test "pops a message off the queue in order", _context do
    Conman.MessageQueue.push(:an_id, %{payload: "A Message"})
    Conman.MessageQueue.push(:another_id, %{payload: "Another Message"})
    message_pack = Conman.MessageQueue.pop()

    now = :erlang.system_time(:nano_seconds)

    assert message_pack.id == :an_id
    assert now - message_pack.locked_at < 100000
    assert message_pack.messages == [%{payload: "A Message"}]
  end

  test "returns nil if pop is called on an empty queue", _context do
    assert Conman.MessageQueue.pop() == nil
  end

  test "increments the lock count when popping a message off", _context do
    Conman.MessageQueue.push(:an_id, %{payload: "A Message"})

    assert Conman.MessageQueue.locked_count == 0
    Conman.MessageQueue.pop()
    assert Conman.MessageQueue.locked_count == 1
  end

  test "only pops messages off the first unlocked connection", _context do
    Conman.MessageQueue.push(:an_id, %{payload: "A Message"})
    Conman.MessageQueue.pop() # locks :an_id
    Conman.MessageQueue.push(:an_id, %{payload: "A Second Message"})
    Conman.MessageQueue.push(:second_id, %{payload: "Yet Another Message"})

    assert Conman.MessageQueue.pop.id == :second_id
  end

  test "unlock allows messages that came in while locked to be retrieved", _context do
    Conman.MessageQueue.push(:an_id, %{payload: "A Message"})
    message_pack = Conman.MessageQueue.pop() # locks :an_id
    Conman.MessageQueue.push(:an_id, %{payload: "Another Message"})

    assert Conman.MessageQueue.pop() == nil

    Conman.MessageQueue.unlock(:an_id, message_pack.locked_at)

    assert Conman.MessageQueue.pop().messages == [%{payload: "Another Message"}]
  end

  test "unlock decrements the locked_count", _context do
    Conman.MessageQueue.push(:an_id, %{payload: "A Message"})
    message_pack = Conman.MessageQueue.pop() # locks :an_id

    assert Conman.MessageQueue.locked_count() == 1
    Conman.MessageQueue.unlock(:an_id, message_pack.locked_at)
    assert Conman.MessageQueue.locked_count() == 0
  end
end
