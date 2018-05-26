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

  def test_json_string() do
    """
    {
      "from": "from@test.com",
      "to": "to@test.com",
      "cc": "cc@test.com",
      "bcc": "bcc@test.com",
      "subject": "Test Subject",
      "text": "Hello Text! <%= name %>",
      "html": "Hello HTML! <%= name %>",
      "data": {
        "name": "Test Name"
      }
    }
    """
    |> String.trim()
  end
end
