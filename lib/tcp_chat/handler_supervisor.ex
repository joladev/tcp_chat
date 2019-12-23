defmodule TcpChat.HandlerSuperviser do
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(opts) do
    child_spec = {TcpChat.Handler, opts}

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
