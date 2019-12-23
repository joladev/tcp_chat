# TcpChat

Sample Elixir TCP chat app, without using dependencies. Interacts directly with `:gen_tcp`. Supports multiple concurrent users, channels and DMs.

Start with `PORT=9999 mix run --no-halt`.

Connect with `telnet <host> <port>`.