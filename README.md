# ConmanElixir

ConmanElixir is a project to proxy a number of TLS-protected TCP
connections to one or more clients, who receive the TCP messages via
HTTP requests. Currently two forms of message are suported:

* Binary messages with a 4-byte length prefix
* Text-based message delimited by newlines

There are two sorts of clients:

* Clients that connect via the TCP connection and deliver and recieve
  messages over that socket. These we will call "TCP Clients". When a
  TCP client sends a message, it is queued until retrieved by an HTTP
  client (see below).
* Clients that connect via the HTTP server and retrieve messages from
  a TCP client and optionally send messages back. These are called
  "HTTP clients".

HTTP Clients can use the following end points to interact with the
server:

* GET / - this retrieves all the currently-queued messages for a TCP
  client. The TCP client is chosen based on how long it's been waiting
  to be processed.
* GET /finished - This indicates that the HTTP client is done
  processing the messages from the TCP connection. Currently, if an
  HTTP client takes longer than 15 seconds to process a request, it is
  assumed that the client has crashed, and the messages are
  re-enqueued to be processed by another HTTP client.
* POST /send - this sends a base64-encoded message to the TCP
  client. The message is decoded before being sent.
* GET /stats - returns a JSON-encoded response containing various
  statistics about the server.
* GET /ip - Returns a list of IP addresses for the TCP clients
  connected to this server.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add conman_elixir to your list of dependencies in `mix.exs`:

        def deps do
          [{:conman_elixir, "~> 0.0.1"}]
        end

  2. Ensure conman_elixir is started before your application:

        def application do
          [applications: [:conman_elixir]]
        end
