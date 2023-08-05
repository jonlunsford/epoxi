# test/epoxi/adapters/smtp_test.exs
defmodule Epoxi.Adapters.SMTPTest do
  use ExUnit.Case

  alias Epoxi.Test.Helpers
  alias Epoxi.Adapters.SMTP

  test "send_blocking/3 returns success" do
    [context, email, _message] = Helpers.build_send_args()

    assert {:ok, _response} = SMTP.send_blocking(email, context.config)
  end

  test "send/3 returns success" do
    [context, email, _message] = Helpers.build_send_args()

    assert {:ok, _response} = SMTP.send(email, context.config)
  end

  test "deliver/3 returns success" do
    context = %Epoxi.TestContext{}
    config = Map.to_list(context.config)

    {:ok, socket} = :gen_smtp_client.open(config)

    emails = Helpers.generate_emails(1)

    assert {:ok, _response} = SMTP.deliver(emails, socket)
  end

  test "deliver/3 handles many sends with the same socket" do
    context = %Epoxi.TestContext{}
    config = Map.to_list(context.config)

    {:ok, socket} = :gen_smtp_client.open(config)

    emails = Helpers.generate_emails(10)

    assert {:ok, _response} = SMTP.deliver(emails, socket)
  end
end
