defmodule Conman.ConnectionMapTest do
  use ExUnit.Case

  doctest Conman.ConnectionMap

  setup do
    Conman.ConnectionMap.clear

    { :ok, [connection_id: "a Connection id",
            connection: "a connection"] }
  end

  test "add returns successfully", context do
    assert Conman.ConnectionMap.add(context[:connection_id], context[:connection]) == :ok
  end

  test "add increments the results of count()", context do
    assert Conman.ConnectionMap.count() == 0
    assert Conman.ConnectionMap.add(context[:connection_id], context[:connection]) == :ok
    assert Conman.ConnectionMap.count() == 1
  end

  test "add allows the connection to be retrieved via get()", context do
    Conman.ConnectionMap.add(context[:connection_id], context[:connection])

    assert Conman.ConnectionMap.get(context[:connection_id]) == context[:connection]
  end

  test "remove returns successfully", context do
    Conman.ConnectionMap.add(context[:connection_id], context[:connection])

    assert Conman.ConnectionMap.remove(context[:connection_id]) == :ok
  end

  test "remove decrements the results of count()", context do
    Conman.ConnectionMap.add(context[:connection_id], context[:connection])

    assert Conman.ConnectionMap.count() == 1
    Conman.ConnectionMap.remove(context[:connection_id])
    assert Conman.ConnectionMap.count() == 0
  end

  test "remove stops the connection from being retrievable with get()", context do
    Conman.ConnectionMap.add(context[:connection_id], context[:connection])
    Conman.ConnectionMap.remove(context[:connection_id])

    assert Conman.ConnectionMap.get(context[:connection_id]) == :nothing
  end

  test "alias should probably do something at some point"
end
