defmodule Epoxi.TestSmtpServer do
  @moduledoc """
  A simple SMTP server for testing purposes.
  """
  @behaviour :gen_smtp_server_session

  alias Epoxi.TestSmtpErrorCodes

  def start(port) do
    :gen_smtp_server.start(
      __MODULE__,
      [[], [{:allow_bare_newlines, true}, {:port, port}]]
    )
  end

  @impl true
  def init(hostname, _session_count, _address, options) do
    banner = [hostname, " ESMTP (Epoxi Local Test SMTP)"]
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
  def handle_RCPT(to, state) do
    # Check if email contains a test code flag (test+CODE@domain.com)
    case Regex.run(~r/test\+([a-z0-9_]+)@/, to) do
      [_, code] ->
        case TestSmtpErrorCodes.get(code) do
          %{message: error_message} ->
            {:error, error_message, state}

          nil ->
            # Default: accept recipient if code not found
            {:ok, state}
        end

      # Default: accept recipient if no code pattern found
      nil ->
        {:ok, state}
    end
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
  def handle_VRFY(_address, state) do
    {:ok, state}
  end

  @impl true
  def handle_STARTTLS(state) do
    {:ok, state}
  end

  @impl true
  def handle_other("PING", _args, state) do
    {["250 OK: PONG"], state}
  end

  @impl true
  def terminate(_reason, state) do
    {:ok, state}
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
