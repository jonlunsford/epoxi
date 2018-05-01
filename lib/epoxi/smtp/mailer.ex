defmodule Epoxi.SMTP.Mailer do
  @moduledoc "Responsible for sending emails to particular hosts"

  alias Epoxi.SMTP.Parsing

  @doc "Delivers email using the passed in context_module"
  @spec deliver(email :: %Mailman.Email{}, context_module :: Module.t()) :: {:ok, deliverd_email :: String.t()} | {:error, reason :: Atom.t(), details :: Tuple.t()}
  def deliver(%Mailman.Email{to: [to | _]} = email, context_module \\ Application.get_env(:epoxi, :context_module)) do
    hostname = Parsing.get_hostname(to)
    context = context_module.set(hostname)

    Mailman.deliver(%{email | to: [to]}, context)
  end

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
