defmodule Conman.CowboyHandlers.SendCommand do
  require Logger

  def init(_proto, req, _opts) do
    Logger.debug  "SendCommand init!"
    { :ok, req, {} }
  end

  def handle(req, state) do
    Logger.debug "SendCommand handle!"

    {id, _} = :cowboy_req.qs_val("id", req)
    { :ok, request_body, req2 } = :cowboy_req.body(req)

    Logger.debug("handle sending command back! #{id}, #{request_body}")
    {:ok, decoded} = Base.decode64(String.replace(request_body, "\n", ""))
    Logger.debug("decoded command: #{List.flatten(:io_lib.format("~p", [decoded]))}")
    Conman.OutgoingQueue.send_message(id, decoded)

    { :ok, req2, state }
  end

  def terminate(_, _, _) do
    Logger.debug "SendCommand terminate!"
    :ok
  end
end
