defmodule EpoxiTest do
  use ExUnit.Case
  alias Epoxi.{Email, Context}
  doctest Epoxi

  setup do
    context = Context.new()

    {:ok, %{context: context}}
  end

  test "send/2 sends an email" do
    assert {:ok, _receipt} =
             Epoxi.send(
               %Email{
                 from: "sender@example.com",
                 to: ["recipient@localhost.com"],
                 subject: "Hello from Epoxi",
                 html: "<p>This is a test email</p>",
                 text: "This is a test email"
               },
               port: 2525,
               relay: "localhost"
             )
  end

  test "send_async/2 sends an email" do
    callback = fn response ->
      assert response == :ok
    end

    Epoxi.send_async(
      %Email{
        from: "sender@example.com",
        to: ["recipient@localhost.com"],
        subject: "Hello from Epoxi",
        html: "<p>This is a test email</p>",
        text: "This is a test email"
      },
      [
        port: 2525,
        relay: "localhost"
      ],
      callback
    )
  end

  test "send_bulk/2 sends many emails" do
    email_a = %Email{
      from: "sender@example.com",
      to: ["recipient_a@localhost.com"],
      subject: "Hello from Epoxi",
      html: "<p>This is a test email</p>",
      text: "This is a test email"
    }

    email_b = %Email{
      from: "sender@example.com",
      to: ["recipient_b@localhost.com"],
      subject: "Hello from Epoxi",
      html: "<p>This is a test email</p>",
      text: "This is a test email"
    }

    assert {:ok, _response} = Epoxi.send_bulk([email_a, email_b], port: 2525, relay: "localhost")
  end
end
