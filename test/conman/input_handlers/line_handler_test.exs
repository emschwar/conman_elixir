defmodule Conman.InputHandlers.LineHandlerTest do
  use ExUnit.Case

  alias Conman.InputHandlers.LineHandler, as: L

  doctest Conman.InputHandlers.LineHandler

  test "returns a full line if given one", _context do
    expected = {"0.1::this_is_a_full_line()", ""}
    assert L.input_received("", "0.1::this_is_a_full_line()\n") == expected
  end

  test "returns a partial line if no newline occurs", _context do
    expected = {:nothing, "0.1::this_is_not_a_full_line"}
    assert L.input_received("0.1::this_is_not_a", "_full_line") == expected
  end

  test "assembles a full line from a partial line and another part", _context do
    expected = {"0.1::this_is_a_full_line()", ""}
    assert L.input_received("0.1::this_is_", "a_full_line()\n") == expected
  end
end
