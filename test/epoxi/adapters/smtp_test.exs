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
end
