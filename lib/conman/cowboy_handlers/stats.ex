defmodule Conman.CowboyHandlers.Stats do
  require Logger

  def init(_proto, req, _opts) do
    Logger.debug  "Stats init!"
    { :ok, req, {} }
  end

  def handle(req, state) do
    Logger.debug "Stats handle!"

    {:ok, reply} = JSON.encode(%{num_connections: Conman.ConnectionMap.count,
                                 num_recevied_messages: Conman.MessageQueue.count,
                                 num_sent_messages: Conman.OutgoingQueue.total_count,
                                 num_stored_messages: Conman.OutgoingQueue.stored_count,
                                 num_locked_queues: Conman.MessageQueue.locked_count})

    {:ok, response} = :cowboy_req.reply(200, [{"content-type", "application/json"}], reply, req)

    { :ok, response, state }
  end

  def terminate(_, _, _) do
    Logger.debug "Stats terminate!"
    :ok
  end
end
