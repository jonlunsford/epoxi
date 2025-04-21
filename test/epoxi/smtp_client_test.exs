# test/epoxi/adapters/smtp_test.exs
defmodule Epoxi.SmtpClientTest do
  use ExUnit.Case, async: true

  alias Epoxi.Test.Helpers
  alias Epoxi.{SmtpClient, SmtpConfig}

  test "send_blocking/3 returns success" do
    [context, email, _message] = Helpers.build_send_args()

    assert {:ok, "1\r\n"} = SmtpClient.send_blocking(email, context)
  end

  test "send_asyn/3 returns success" do
    [context, email, _message] = Helpers.build_send_args()

    assert :ok = SmtpClient.send_async(email, context, fn _response -> nil end)
  end

  test "send_bulk/3 returns success" do
    [context, email, _message] = Helpers.build_send_args()

    assert {:ok, _response} = SmtpClient.send_bulk([email], context, "test.com")
  end

  test "send_bulk/3 handles many sends with the same socket" do
    [context, _email, _message] = Helpers.build_send_args()

    emails = Helpers.generate_emails(10)

    assert {:ok, _response} = SmtpClient.send_bulk(emails, context, "test.com")
  end

  test "send_bulk/3 handles many errors with the same socket" do
    [context, _email, _message] = Helpers.build_send_args()

    emails =
      Helpers.generate_emails(10, fn index ->
        error_code = if rem(index, 2) == 0, do: "422", else: "200"
        %{to: ["test+#{error_code}@test.com"]}
      end)

    {:ok, response} = SmtpClient.send_bulk(emails, context, "test.com")

    failure = response.failure
    success = response.success

    assert length(failure) == 5
    assert length(success) == 5
  end

  test "send_over_socket/2 sends all emails over the same socket" do
    [email] = Helpers.generate_emails(1)

    {:ok, socket} =
      SmtpConfig.open_socket(
        %Epoxi.SmtpConfig{
          port: 2525,
          relay: "localhost"
        },
        "localhost"
      )

    email = SmtpClient.send_over_socket(email, socket)

    assert email.status == :delivered
  end

  test "send_over_socket/2 handles errors" do
    [email] = Helpers.generate_emails(1, fn _ -> %{to: ["test+503@localhost.com"]} end)

    {:ok, socket} =
      SmtpConfig.open_socket(
        %Epoxi.SmtpConfig{
          port: 2525,
          relay: "localhost"
        },
        "localhost"
      )

    email = SmtpClient.send_over_socket(email, socket)

    assert email.status == :failed
  end
end
