defmodule Epoxi.SMTP.ContextTest do
  use ExUnit.Case

  alias Epoxi.SMTP.Context

  describe "set" do
    test "it returns a %Mailman.Context{} struct" do
      expected = %Mailman.Context{
        config: %Mailman.SmtpConfig{
          relay: "mx.test.com",
          port: 25,
          auth: :never,
          tls: :always
        },
        composer: %Mailman.EexComposeConfig{}
      }

      assert Context.set("mx.test.com") == expected
    end
  end
end
