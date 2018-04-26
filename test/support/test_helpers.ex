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
end
