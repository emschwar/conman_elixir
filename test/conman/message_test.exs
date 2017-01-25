defmodule Conman.MessageTest do
  use ExUnit.Case

  doctest Conman.Message

  test "new makes a non-control message struct" do
    %Conman.Message{control: false} = Conman.Message.new("sender", "message")
  end

  test "new allows clients to specify control" do
    %Conman.Message{control: true} = Conman.Message.new("sender", "message", true)
  end

  test "disconnected creates a control message that is a hash" do
    message = Conman.Message.disconnected("sender")
    now = :erlang.system_time(:seconds)

    assert message.sender == "sender"
    assert message.control == true
    assert message.payload.message == "closed"
    assert now - message.payload.received_at < 1
  end

  test "encoding a non-control message returns json with base64-encoded message" do
    message = Conman.Message.new("sender", "message")
    { :ok, encoded } = Conman.Message.to_json(message)

    assert { :ok, decoded } = JSON.decode(encoded)
    assert decoded["headers"]["control"] == false
    assert decoded["headers"]["sender"] == "sender"
    assert decoded["payload"] == Base.encode64("message")
  end

  test "encoding a control message returns json with base64-encoded json message" do
    message = Conman.Message.disconnected("sender")
    { :ok, encoded } = Conman.Message.to_json(message)
    now = :erlang.system_time(:seconds)

    assert { :ok, decoded } = JSON.decode(encoded)
    assert decoded["headers"]["control"] == true
    assert decoded["headers"]["sender"] == "sender"

    {:ok, decoded_payload} = Base.decode64(decoded["payload"])
    {:ok, json_payload} = JSON.decode(decoded_payload)
    assert now - json_payload["received_at"] < 2
    assert json_payload["message"] == "closed"
  end
end
