defmodule Epoxi.Support.Server do
  @moduledoc "Fake SMTP server for testing purposes only"

  require Logger
  use GenServer

  @initial_state %{socket: nil}

  def init(state) do
    opts = [:binary, packet: :raw, active: false]
    {:ok, socket} = :gen_tcp.listen(9876, opts)
    {:ok, %{state | socket: socket}}
  end

  def start_link do
    GenServer.start_link(__MODULE__, @initial_state)
  end

  def send(pid, message) do
    GenServer.call(pid, message)
  end

  def handle_call("EHLO localhost\r\n" = _message, _from, state) do
    reply = """
            250-example.com\r
            250-PIPELINING\r
            250-SIZE 10240000\r
            250-VRFY\r
            250-ETRN\r
            250-STARTTLS\r
            250-ENHANCEDSTATUSCODES\r
            250-8BITMIME\r
            250 DSN\r
            """

    :gen_tcp.send(state.socket, reply)

    {:reply, reply, state}
  end

  def handle_call(request, from, state) do
    super(request, from, state)
  end
end
