defmodule Epoxi.Mail.SenderTest do
  use ExUnit.Case

  alias Epoxi.Test.Helpers

  setup do
    Mailman.TestServer.start

    test_email = Helpers.email_to(["test@localhost.com"])
    consumer = start_supervised!({Epoxi.Mail.Sender, test_email})

    %{consumer: consumer}
  end

  describe "handle_info(:send)" do
    test "this works", %{consumer: _consumer} do
    end
  end
end
