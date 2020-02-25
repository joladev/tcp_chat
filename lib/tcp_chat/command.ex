defmodule TcpChat.Command do
  import TcpChat.Send

  def handle_message(%{client: client, handle: handle} = state, "QUIT" <> _rest) do
    send_everyone_else({:quit, handle})
    :gen_tcp.send(client, "Goodbye!\n")
    :gen_tcp.close(client)
    state
  end

  def handle_message(%{client: client, handle: handle, channel: channel} = state, "LEAVE" <> _rest) do
    send_everyone_in_channel(channel, {:leave, handle})
    :gen_tcp.send(client, "Left channel #{channel}.\n")
    %{state | channel: nil}
  end

  def handle_message(%{handle: handle, channel: channel} = state, message) when not is_nil(channel) do
    send_everyone_in_channel(channel, {:message, handle, message})
    state
  end

  def handle_message(%{client: client} = state, "REGISTER " <> handle) do
    handle = String.trim(handle)
    :gen_tcp.send(client, "Registered #{handle} to this client.\n")

    Registry.register(TcpChat.Registry, handle, nil)
    send_everyone_else({:register, handle})

    %{state | handle: handle}
  end

  def handle_message(%{client: client, handle: nil} = state, _) do
    :gen_tcp.send(client, "You must REGISTER before you can chat.\n")
    state
  end

  def handle_message(%{client: client, handle: handle} = state, "JOIN " <> channel) do
    channel = String.trim(channel)

    Registry.update_value(TcpChat.Registry, handle, fn _ -> channel end)
    send_everyone_in_channel(channel, {:join, handle})
    :gen_tcp.send(client, "Joined channel #{channel}.\n")

    %{state | channel: channel}
  end

  def handle_message(%{client: client, handle: handle} = state, "WHOAMI" <> _rest) do
    :gen_tcp.send(client, "You are #{handle}.\n")
    state
  end

  def handle_message(%{client: client, handle: sender} = state, "DM " <> command) do
    case Regex.named_captures(~r/^(?<recipient>\w+)\s(?<message>.+)$/, command) do
      nil ->
        :gen_tcp.send(client, "Invalid format for DM command. Expects DM <handle> <message>.\n")

      %{"recipient" => recipient, "message" => message} ->
        case Registry.lookup(TcpChat.Registry, recipient) do
          [{pid, _value}] ->
            GenServer.cast(pid, {:message, sender, message})
            :gen_tcp.send(client, "Sent message to #{recipient}.\n")

          _ ->
            :gen_tcp.send(client, "No such user: #{recipient}.\n")
        end
    end

    state
  end

  def handle_message(%{client: client} = state, "LIST" <> _rest) do
    handles =
      registered_handles()
      |> Enum.map(fn {handle, _, _} -> handle end)

    :gen_tcp.send(client, "All registered handles:\n#{inspect(handles)}\n")
    state
  end

  def handle_message(%{client: client} = state, command) do
    :gen_tcp.send(client, "Unrecognized command: #{command}\n")
    state
  end
end
