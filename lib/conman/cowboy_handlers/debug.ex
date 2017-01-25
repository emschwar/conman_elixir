defmodule Conman.CowboyHandlers.Debug do
  def onrequest_hook(req) do
    method = debug_string(extract(:cowboy_req.method(req)))
    path = debug_string(extract(:cowboy_req.path(req)))
    params = params_to_string(extract(:cowboy_req.qs_vals(req)))
    host = debug_string(extract(:cowboy_req.host(req)))
    port = port_to_string(extract(:cowboy_req.port(req)))

    IO.puts """

Started #{method} #{path}#{params} for #{host}#{port}
    qs_vals  : #{to_native_string(extract(:cowboy_req.qs_vals(req)))}
    raw_qs   : #{to_native_string(extract(:cowboy_req.qs(req)))}
    bindings : #{to_native_string(extract(:cowboy_req.bindings(req)))}
    cookies  : #{to_native_string(extract(:cowboy_req.cookies(req)))}
    headers  : #{to_native_string(extract(:cowboy_req.headers(req)))}
    """

    req
  end

  def onresponse_hook(code, headers, response, req) do
    method = debug_string(extract(:cowboy_req.method(req)))
    path = debug_string(extract(:cowboy_req.path(req)))
    params = params_to_string(extract(:cowboy_req.qs_vals(req)))
    host = debug_string(extract(:cowboy_req.host(req)))
    port = port_to_string(extract(:cowboy_req.port(req)))

    IO.puts """

Completed #{debug_string(code)} #{method} #{path}#{params} for #{host}#{port}
    cookies  : #{to_native_string(extract(:cowboy_req.cookies(req)))}
    headers  : #{to_native_string(headers)}
    response : #{to_native_string(response)}
    """

    req
  end

  defp extract({value, _req}), do: value

  defp port_to_string(port) do
    case debug_string(port) do
      '80' -> ''
      other -> ':' ++ other
    end
  end

  defp params_to_string(params) do
    case debug_string(params) do
      '' -> ''
      other -> '?' ++ other
    end
  end

  defp to_native_string(value) do
    :io_lib.format('~p', [value])
  end

  defp debug_string(:undefined), do: ''
  defp debug_string(atom) when is_atom(atom), do: :erlang.atom_to_list(atom)
  defp debug_string(binary) when is_binary(binary), do: :erlang.binary_to_list(binary)
  defp debug_string(int) when is_integer(int), do: :erlang.integer_to_list(int)
  defp debug_string([]), do: ''
  defp debug_string(list) when is_list(list), do: debug_string(list, "")

  defp debug_string(binary, separator) when is_binary(binary) do
    debug_string(:erlang.binary_to_list(binary), separator)
  end
  defp debug_string(list, separator) when is_list(list) do
    :string.join(list_to_string(list, []), separator)
  end

  defp list_to_string([], result), do: Enum.reverse(result)
  defp list_to_string([head|rest], result) do
    list_to_string(rest, [debug_string(head) | result])
  end
end
