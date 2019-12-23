defmodule TcpChat.Handler do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    client = Keyword.get(opts, :client)

    :gen_tcp.send(
      client,
      "Welcome to the chat server!\n\nCommands:\nQUIT\nREGISTER <handle>\nWHOAMI\nLIST\nDM <handle> <message>\n\n"
    )

    {:ok, %{client: client, handle: nil, channel: nil}}
  end

  def handle_info({:tcp, _port, message}, %{client: client} = state) do
    state = handle_message(state, message)

    :inet.setopts(client, active: :once)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _port}, %{handle: handle} = state) do
    send_everyone_else({:quit, handle})
    {:stop, :normal, state}
  end

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

  def handle_cast({:message, sender, message}, %{client: client} = state) do
    :gen_tcp.send(client, "#{sender}: #{message}\n")

    {:noreply, state}
  end

  def handle_cast({:register, handle}, %{client: client} = state) do
    :gen_tcp.send(client, ">>> #{handle} just registered!\n")

    {:noreply, state}
  end

  def handle_cast({:quit, handle}, %{client: client} = state) do
    :gen_tcp.send(client, ">>> #{handle} just quit!\n")

    {:noreply, state}
  end

  def handle_cast({:join, handle}, %{client: client} = state) do
    :gen_tcp.send(client, ">>> #{handle} just joined channel!\n")

    {:noreply, state}
  end

  def handle_cast({:leave, handle}, %{client: client} = state) do
    :gen_tcp.send(client, ">>> #{handle} just left channel!\n")

    {:noreply, state}
  end

  defp registered_handles() do
    Registry.select(TcpChat.Registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
  end

  defp in_channel(channel) do
    Registry.select(TcpChat.Registry, [{{:"$1", :"$2", channel}, [], [{{:"$1", :"$2", :_}}]}])
  end

  defp send_everyone_else(message) do
    entries = registered_handles()

    entries
    |> Enum.filter(fn {_, pid, _} -> pid !== self() end)
    |> Enum.each(fn {_, pid, _} -> GenServer.cast(pid, message) end)
  end

  defp send_everyone_in_channel(channel, message) do
    entries = in_channel(channel)

    entries
    |> Enum.filter(fn {_, pid, _} -> pid !== self() end)
    |> Enum.each(fn {_, pid, _} -> GenServer.cast(pid, message) end)
  end
end
