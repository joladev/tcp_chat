defmodule TcpChat.Acceptor do
  require Logger

  def accept(port) do
    Logger.info("Listening on #{port}.")

    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: :once, reuseaddr: true])

    loop_accept(socket)
  end

  def loop_accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} = TcpChat.HandlerSuperviser.start_child(client: client)
    :gen_tcp.controlling_process(client, pid)

    loop_accept(socket)
  end
end
