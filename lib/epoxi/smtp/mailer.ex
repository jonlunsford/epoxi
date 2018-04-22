defmodule Epoxi.SMTP.Mailer do
  @moduledoc "Responsible for sending emails to particular hosts"

  alias Epoxi.SMTP.{Router, Context, Parsing}

  def deliver(%Mailman.Email{to: [to | _]} = email) do
    hostname = Parsing.get_hostname(to)
    mx_records = Router.get_mx_hosts(hostname)
    {_distance, mx_host} = List.first(mx_records)
    context = Context.set(mx_host)

    Mailman.deliver(email, context)
  end
end
