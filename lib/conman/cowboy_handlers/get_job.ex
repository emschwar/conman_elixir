defmodule Conman.CowboyHandlers.GetJob do
  require Logger

  def init(_proto, req, _opts) do
    Logger.debug  "GetJob init!"
    { :ok, req, {} }
  end

  def handle(req, state) do
    Logger.debug "GetJob handle!"
    case Conman.MessageQueue.pop do
      %Conman.MessagePack{id: id, message_count: message_count, messages: messages, locked_at: locked_at} ->
        :io.format('messages: ~p~n', [messages])
        encoded_messages = messages
                           |> Stream.map(&Conman.Message.to_json/1)
                           |> Stream.map(&elem(&1, 1))
                           |> Enum.to_list

        {:ok, reply} = JSON.encode(%{socket_id: id,
                                     message_count: message_count,
                                     messages: encoded_messages,
                                     locked_at: locked_at})
        Logger.debug "GetJob reply: #{reply}"
        {:ok, response} = :cowboy_req.reply(200, [{"content-type", "application/json"}], reply, req)
        {:ok, response, state}
      anythingelse ->
        :io.format('NO messages!: ~p~n', [anythingelse])
        {:ok, reply} = JSON.encode(%{message_count: 0,
                                     messages: []})
        Logger.debug "GetJob reply: #{reply}"
        { :ok, response} = :cowboy_req.reply(200, [{"content-type", "application/json"}], reply, req)
        { :ok, response, state }
    end
  end

  def terminate(_, _, _) do
    Logger.debug "GetJob terminate!"
    :ok
  end
end
