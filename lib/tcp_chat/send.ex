defmodule TcpChat.Send do
  def send_everyone_else(message) do
    entries = registered_handles()

    entries
    |> Enum.filter(fn {_, pid, _} -> pid !== self() end)
    |> Enum.each(fn {_, pid, _} -> GenServer.cast(pid, message) end)
  end

  def send_everyone_in_channel(channel, message) do
    entries = in_channel(channel)

    entries
    |> Enum.filter(fn {_, pid, _} -> pid !== self() end)
    |> Enum.each(fn {_, pid, _} -> GenServer.cast(pid, message) end)
  end

  def registered_handles() do
    Registry.select(TcpChat.Registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
  end

  def in_channel(channel) do
    Registry.select(TcpChat.Registry, [{{:"$1", :"$2", channel}, [], [{{:"$1", :"$2", :_}}]}])
  end
end
