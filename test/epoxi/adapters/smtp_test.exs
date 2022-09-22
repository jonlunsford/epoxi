# test/epoxi/adapters/smtp_test.exs
defmodule Epoxi.Adapters.SMTPTest do
  use ExUnit.Case

  alias Epoxi.Test.Helpers
  alias Epoxi.Adapters.SMTP

  test "send_blocking/3 returns success" do
    [context, email, message] = Helpers.build_send_args()

    assert {:ok, _response} =
             SMTP.send_blocking(
               context.config,
               email,
               message
             )
  end

  test "send/3 returns success" do
    [context, email, message] = Helpers.build_send_args()

    assert {:ok, _response} =
             SMTP.send(
               context.config,
               email,
               message
             )
  end

  test "deliver/3 returns success" do
    [context, email, message] = Helpers.build_send_args()
    config = Map.to_list(context.config)

    {:ok, socket} = :gen_smtp_client.open(config)

    assert {:ok, _response} =
             SMTP.deliver(
               socket,
               email,
               message
             )
  end

  test "deliver/3 handles many sends with the same socket" do
    context = %Epoxi.TestContext{}
    config = Map.to_list(context.config)

    {:ok, socket} = :gen_smtp_client.open(config)

    emails = Helpers.generate_emails(10)

    Enum.each(emails, fn (email) ->
      message = Epoxi.Render.encode(email)

      assert {:ok, _response} =
               SMTP.deliver(
                 socket,
                 emails
               )
    end)
  end
end
