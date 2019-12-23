defmodule TcpChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    port = String.to_integer(System.fetch_env!("PORT"))

    children = [
      {Registry, [name: TcpChat.Registry, keys: :unique]},
      {TcpChat.HandlerSuperviser, []},
      {Task, fn -> TcpChat.Acceptor.accept(port) end}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TcpChat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
