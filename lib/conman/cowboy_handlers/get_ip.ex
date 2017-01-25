defmodule Conman.CowboyHandlers.GetIp do
  require Logger

  def init(_proto, req, _opts) do
    Logger.debug  "GetIp init!"
    { :ok, req, {} }
  end

  def handle(req, state) do
    Logger.debug "GetIp handle!"

    {:ok, reply} = JSON.encode(%{ips: Enum.map(Conman.ConnectionMap.ips, &to_string/1)})
    {:ok, response} = :cowboy_req.reply(200, [{"content_type", "application/json"}], reply, req)

    {:ok, response, state}
  end

  def terminate(_, _, _) do
    Logger.debug "GetIp terminate!"
    :ok
  end
end
