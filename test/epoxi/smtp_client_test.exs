# test/epoxi/adapters/smtp_test.exs
defmodule Epoxi.SmtpClientTest do
  use ExUnit.Case

  alias Epoxi.Test.Helpers
  alias Epoxi.SmtpClient

  test "send_blocking/3 returns success" do
    [context, email, _message] = Helpers.build_send_args()

    assert {:ok, "1\r\n"} = SmtpClient.send_blocking(email, context)
  end

  test "send/3 returns success" do
    [context, email, _message] = Helpers.build_send_args()

    assert :ok = SmtpClient.send_async(email, context, fn _response -> nil end)
  end

  test "deliver/3 returns success" do
    [context, email, _message] = Helpers.build_send_args()

    assert {:ok, _response} = SmtpClient.send_bulk([email], context)
  end

  test "deliver/3 handles many sends with the same socket" do
    [context, _email, _message] = Helpers.build_send_args()

    emails = Helpers.generate_emails(10)

    assert {:ok, _response} = SmtpClient.send_bulk(emails, context)
  end
end
