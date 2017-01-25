defmodule Conman.CowboyHandlers.FinishJob do
  require Logger

  def init(_proto, req, _opts) do
    Logger.debug  "FinishJob init!"
    { :ok, req, {} }
  end

  def handle(req, state) do
    Logger.debug "FinishJob handle!"

    {id, req2} = :cowboy_req.qs_val("id", req)
    {locked_str, req3} = :cowboy_req.qs_val("locked_at", req2)

    Logger.debug "finished_job: id: #{id}, locked_at: #{locked_str}"
    {locked_at, ""} = Integer.parse(locked_str)
    Conman.MessageQueue.unlock(id, locked_at)

    {:ok, reply} = :cowboy_req.reply(200, [{"content-type", "text/plain"}], "finished!", req3)

    {:ok, reply, state}
  end

  def terminate(_, _, _) do
    Logger.debug "FinishJob terminate!"
    :ok
  end
end
