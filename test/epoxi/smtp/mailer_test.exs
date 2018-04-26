defmodule Epoxi.SMTP.MailerTest do
  use ExUnit.Case

  alias Epoxi.SMTP.Mailer

  alias Epoxi.Test.Helpers
  alias Epoxi.Test.Context

  setup_all do
    Mailman.TestServer.start
    :ok
  end

  describe  "deliver" do
    test "it succeeds" do
      email = Helpers.email_to(["test@gmail.com"])

      assert {:ok, _message} = Mailer.deliver(email, Context)
    end

    test "it handles long form addresses" do
      email = Helpers.email_to(["Test Tester <test@gmail.com>"])

      assert {:ok, _message} = Mailer.deliver(email, Context)
    end
  end
end
