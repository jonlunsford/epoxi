# credo:disable-for-this-file
defmodule Epoxi.SmtpServer do
  @moduledoc """
  SMTP server that relays mail
  """

  @behaviour :gen_smtp_server_session

  def start(port) do
    :gen_smtp_server.start(
      __MODULE__,
      [{:allow_bare_newlines, true}, {:port, port}]
    )
  end

  @impl true
  def init(hostname, _session_count, _address, options) do
    banner = [hostname, " ESMTP (Epoxi SMTP)"]
    {:ok, banner, options}
  end

  @impl true
  def handle_DATA(_from, _to, _data, state) do
    {:ok, "1", state}
  end

  @impl true
  def handle_EHLO(_hostname, extensions, state) do
    {:ok, extensions, state}
  end

  @impl true
  def handle_HELO(_hostname, state) do
    {:ok, 655_360, state}
  end

  @impl true
  def handle_MAIL(_from, state) do
    {:ok, state}
  end

  @impl true
  def handle_MAIL_extension(_extension, state) do
    {:ok, state}
  end

  @impl true
  def handle_RCPT(_to, state) do
    {:ok, state}
  end

  @impl true
  def handle_RCPT_extension(_extension, state) do
    {:ok, state}
  end

  @impl true
  def handle_RSET(state) do
    {:ok, state}
  end

  @impl true
  def handle_VRFY(address, state) do
    {:ok, address, state}
  end

  @impl true
  def handle_STARTTLS(state) do
    {:ok, state}
  end

  @impl true
  def handle_other("PING", _args, _state) do
    {:noreply, "250 OK: PONG"}
  end

  @impl true
  def terminate(reason, state) do
    {:ok, reason, state}
  end

  @impl true
  def code_change(_old, state, _extra) do
    {:ok, state}
  end

  def relay(_, [], _) do
    :ok
  end

  def relay(from, [to | rest], data) do
    host = String.split(to, "@") |> List.last()
    :gen_smtp_client.send({from, [to], String.to_charlist(data)}, [{:relay, host}])
    relay(from, rest, data)
  end
end
