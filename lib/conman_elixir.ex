defmodule ConmanElixir do
  use Application
  require Logger

  def start(_type, args) do
    { :ok, pid } = Conman.Supervisor.start_link(args)
    Logger.debug "Starting ConmanElixirApp!"
    tcp_options = [{:port, 8092},
                   {:max_connections, :infinity},
                   {:versions, :ssl.versions()[:available]},
                   {:certfile, Conman.Certs.cert_path},
                   {:keyfile, Conman.Certs.key_path}]

    Logger.debug "Starting ranch tcp listener!"
    {:ok, _} = :ranch.start_listener(:conman_tcp, 100, :ranch_ssl, tcp_options,
                                     Conman.Socket,
                                     [{:connection_handler, Conman.InputHandlers.LineHandler}])

    Logger.debug "Compiling cowboy router!"
    dispatch = :cowboy_router.compile([
      {:'_', [
            {'/', Conman.CowboyHandlers.GetJob, []},
            {'/send', Conman.CowboyHandlers.SendCommand, []},
            {'/finished', Conman.CowboyHandlers.FinishJob, []},
            {'/stats', Conman.CowboyHandlers.Stats, []},
            {'/ip', Conman.CowboyHandlers.GetIp, []}
          ]}
    ])

    Logger.debug "Starting cowboy http listener!"
    {:ok, _} = :cowboy.start_http(:conman_http_listener, 100,
                                  [{ :port, 8080 }],
      [
        { :env, [{ :dispatch, dispatch }] },
        { :max_keepalive, 1000 }
      ])

    Logger.debug "Started cowboy http listener with pid #{inspect(pid)}!"
    { :ok, pid }
  end
end
