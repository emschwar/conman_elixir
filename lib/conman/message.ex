defmodule Conman.Message do
  defstruct sender: %{},
            control: false,
            payload: %{}

  def new(sender, message, is_control \\ false) do
    %Conman.Message{sender: sender, control: is_control,
                    payload: message}

  end

  def disconnected(sender) do
    new(sender, %{ received_at: :erlang.system_time(:seconds),
                   message: "closed" }, true)
  end

  def to_json(message=%Conman.Message{control: false}) do
    do_json_encode(message)
  end

  def to_json(message=%Conman.Message{control: true}) do
    {:ok, payload} = JSON.encode(message.payload)

    do_json_encode(%Conman.Message{ message | payload: payload })
  end

  defp do_json_encode(message=%Conman.Message{}) do
    JSON.encode(%{headers: %{control: message.control, sender: message.sender},
                  payload: Base.encode64(message.payload)})
  end
end
