defmodule ConmanElixir.Mixfile do
  use Mix.Project

  def project do
    [app: :conman_elixir,
     version: "0.0.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger, :ranch, :cowboy, :uuid],
     mod: {ConmanElixir, []}, # {module, args} to start this application
     registered: [ Conman.ConnectionMap,
                   Conman.MessageQueue,
                   Conman.OutgoingQueue,
                   :conman_tcp,
                   :conman_http_listener ]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ranch, "1.2.0", override: true},
     {:uuid, "~>1.1"},
     {:json, "~>0.3.0"},
     {:cowboy, "1.0.4"}]
  end
end
