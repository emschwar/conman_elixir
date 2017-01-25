defmodule Conman.Supervisor do
  use Supervisor

  def start_link(args) do
    {:ok, _pid} = Supervisor.start_link(__MODULE__, args)
  end

  def init(_args) do
    children = [
      worker(Conman.MessageQueue, []),
      worker(Conman.ConnectionMap, []),
      worker(Conman.OutgoingQueue, [])
    ]

    supervise children, strategy: :one_for_one
  end
end
