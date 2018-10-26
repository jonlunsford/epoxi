defmodule Epoxi.Test.Helpers do
  @moduledoc "Generic test helper functions"

  @spec email_to(recipients :: List.t(String.t())) :: %Mailman.Email{}
  def email_to(recipients) do
    %Mailman.Email{
      subject: "Hello!",
      from: "test@localhost.com",
      to: recipients,
      data: [
        name: "Yo"
      ],
      text: "Hello! <%= name %> These are Unicode: qżźół",
      html: """
            <html>
            <body>
             <b>Hello! <%= name %></b> These are Unicode: qżźół
            </body>
            </html>
            """
    }
  end

  def multi_recipients_json do
    """
    {
      "from": "test@test.com",
      "to": ["test1@test.com", "test2@test.com", "test3@test.com"],
      "subject": "Test Subject",
      "text": "Hello Text! <%= first_name %> <%= last_name %>",
      "html": "Hello HTML! <%= first_name %> <%= last_name %>",
      "data": {
        "test1@test.com": { "first_name": "test1first", "last_name": "test1last" },
        "test2@test.com": { "first_name": "test2first", "last_name": "test2last" },
        "test3@test.com": { "first_name": "test3first", "last_name": "test3last" }
      }
    }
    """
    |> String.trim()
  end

  def test_json_string() do
    """
    {
      "from": "test@test.com",
      "to": ["test1@test.com"],
      "subject": "Test Subject",
      "text": "Hello Text! <%= first_name %> <%= last_name %>",
      "html": "Hello HTML! <%= first_name %> <%= last_name %>",
      "data": {
        "test1@test.com": { "first_name": "test1first", "last_name": "test1last" }
      }
    }
    """
    |> String.trim()
  end
end
