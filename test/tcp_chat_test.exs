defmodule TcpChatTest do
  use ExUnit.Case
  doctest TcpChat

  test "greets the world" do
    assert TcpChat.hello() == :world
  end
end
