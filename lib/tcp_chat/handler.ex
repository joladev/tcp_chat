defmodule TcpChat.Handler do
  use GenServer

  alias TcpChat.{Command, Send}

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
    state = Command.handle_message(state, message)

    :inet.setopts(client, active: :once)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _port}, %{handle: handle} = state) do
    Send.send_everyone_else({:quit, handle})
    {:stop, :normal, state}
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
end
