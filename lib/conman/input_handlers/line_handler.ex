use Bitwise

defmodule Conman.InputHandlers.LineHandler do
  require Logger

  def input_received(buffer, message) do
    all_input = buffer <> message

    case :binary.split(all_input, <<"\n">>) do
      [partial]    ->
        Logger.debug("LineHandler partial: #{inspect(partial)}")
        { :nothing, partial }
      [line, rest] ->
        Logger.debug("LineHandler line, rest: (#{inspect(line)}, #{inspect(rest)})")
        { line, rest }
    end
  end
end
