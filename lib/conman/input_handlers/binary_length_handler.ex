defmodule Conman.InputHandlers.BinaryLengthHandler do
  def input_received(partial, new_input) do
    buffer = <<partial :: binary, new_input :: binary>>
    try do
      <<length :: size(32), message :: binary - size(length), rest :: bits>> = buffer

      { message, rest }
    rescue
      MatchError -> { :nothing, buffer }
    end
  end
end
