defmodule Conman.Certs do
  @cert_path :code.priv_dir(:conman_elixir) ++ '/certs'

  def key_path, do: @cert_path ++ '/key.key'
  def cert_path, do: @cert_path ++ '/key.crt'
end
