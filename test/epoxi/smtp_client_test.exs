# test/epoxi/adapters/smtp_test.exs
defmodule Epoxi.SmtpClientTest do
  use ExUnit.Case, async: true

  alias Epoxi.Test.Helpers
  alias Epoxi.SmtpClient

  setup do
    {:ok, socket} = SmtpClient.connect(port: 2525, relay: "localhost")

    {:ok, %{socket: socket}}
  end

  test "send_blocking/3 returns success" do
    [email] = Helpers.generate_emails(1)

    assert {:ok, "1\r\n"} = SmtpClient.send_blocking(email, port: 2525, relay: "localhost")
  end

  test "send_async/3 returns success" do
    [email] = Helpers.generate_emails(1)

    assert :ok =
             SmtpClient.send_async(
               email,
               [port: 2525, relay: "localhost"],
               fn _response -> nil end
             )
  end

  test "send_batch/2 returns success" do
    emails = Helpers.generate_emails(10)

    assert {:ok, _response} = SmtpClient.send_batch(emails, "localhost")
  end

  test "send_bulk/3 returns success", %{socket: socket} do
    [email] = Helpers.generate_emails(1)

    assert {:ok, _response} = SmtpClient.send_bulk([email], socket)
  end

  test "send_bulk/3 handles many sends with the same socket", %{socket: socket} do
    emails = Helpers.generate_emails(10)

    assert {:ok, _response} = SmtpClient.send_bulk(emails, socket)
  end

  test "send_bulk/3 handles many errors with the same socket", %{socket: socket} do
    emails =
      Helpers.generate_emails(10, fn index ->
        error_code = if rem(index, 2) == 0, do: "422", else: "200"
        %{to: ["test+#{error_code}@test.com"]}
      end)

    {:ok, response} = SmtpClient.send_bulk(emails, socket)

    {success, failure} =
      Enum.split_with(response, fn email ->
        email.status == :delivered
      end)

    assert length(failure) == 5
    assert length(success) == 5
  end
end
