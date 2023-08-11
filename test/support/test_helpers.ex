defmodule Epoxi.Test.Helpers do
  @moduledoc "Generic test helper functions"

  def gen_json_payload(batch_size, attrs \\ %{}) do
    {to_domain, attrs} = Map.pop(attrs, :to_domain)
    data = build_batch_data(batch_size, %{to_domain: to_domain, to: attrs[:to]})
    recipients = Map.keys(data)

    %{
      from: "test@test.com",
      to: recipients,
      subject: "Test Subject",
      text: "Hello Text! <%= first_name %> <%= last_name %>",
      html: "<h3>Hello HTML!</h3> <p><strong><%= first_name %></strong>, <%= last_name %></p>",
      data: data
    }
    |> Map.merge(attrs)
    |> Jason.encode!()
  end

  def build_batch_data(size, opts \\ %{}) do
    1..size
    |> Enum.reduce(%{}, fn num, map ->
      generate_data(num, map, opts)
    end)
  end

  def generate_data(num, map, opts \\ %{}) do
    to_domain = opts[:to_domain] || "test.com"
    email = List.first(opts[:to]) || "test#{num}@#{to_domain}"

    map
    |> Map.put(email, %{
      first_name: "test#{num}first",
      last_name: "test#{num}last"
    })
  end

  def context_for_mailtrap do
    config = %Epoxi.SmtpConfig{
      username: System.get_env("MAILTRAP_USER"),
      password: System.get_env("MAILTRAP_PW"),
      relay: "smtp.mailtrap.io",
      hostname: "mailtrap.io",
      port: 25,
      auth: :always
    }

    %Epoxi.Context{config: config}
  end

  def generate_emails(batch_size) do
    1..batch_size
    |> Enum.map(fn i ->
      build_email(%{to: ["test#{i}@test.com"]})
    end)
  end

  def build_email(email_attrs \\ %{}) do
    attrs =
      %{
        from: "test@test.com",
        to: ["test1@test.com"],
        subject: "Test Subject",
        text: "Hello Text! <%= first_name %> <%= last_name %>",
        html: "Hello HTML! <%= first_name %> <%= last_name %>",
        data: [first_name: "foo", last_name: "bar"]
      }
      |> Map.merge(email_attrs)

    struct(%Epoxi.Email{}, attrs)
  end

  def build_send_args(email_attrs \\ %{}) do
    email = build_email(email_attrs)
    context = %Epoxi.Context{}
    message = Epoxi.Render.encode(email)

    [context, email, message]
  end

  def text_email do
    {"text", "plain",
     [
       {"Received", "by Postfix"},
       {"To", "to@test.com"},
       {"From", "from@test.com"},
       {"Subject", "Sent From Postfix"},
       {"Message-Id", "<20170923214252.8B76EB23D4B@test.com>"},
       {"Date", "Sat, 23 Sep 2017 14:41:55 -0700 (PDT)"}
     ],
     [
       {"content-type-params", [{"charset", "us-ascii"}]},
       {"disposition", "inline"},
       {"disposition-params", []}
     ], "This is some plain text shit."}
  end

  def html_email do
    {"text", "html",
     [
       {"Received", "by Postfix"},
       {"Content-Type", "text/html"},
       {"From", "Acid Burn <acid@burn.com>"},
       {"To", "Zero Cool <zero@cool.com>"},
       {"Subject", "Zero Cool Is Not Cool!"},
       {"Message-Id", "<20170924211056.709EEB26910@Jons-MacBook-Pro.local>"},
       {"Date", "Sun, 24 Sep 2017 14:09:49 -0700 (PDT)"}
     ], [], "<div>Hack The Planet!</div>"}
  end

  def multipart_email do
    {"multipart", "mixed",
     [
       {"Received", "by Postfix"},
       {"From", "Senders Name <sender@test.com>"},
       {"To", "Recipient Name <recipient@test.com>"},
       {"Subject", "Multi-Part Emails"},
       {"MIME-Version", "1.0"},
       {"Content-type", "multipart/mixed; boundary=\"simple boundary\""},
       {"Message-Id", "<20170924215439.E75C4B27054@Jons-MacBook-Pro.local>"},
       {"Date", "Sun, 24 Sep 2017 14:54:36 -0700 (PDT)"}
     ],
     [
       {"content-type-params", [{"boundary", "simple boundary"}]},
       {"disposition", "inline"},
       {"disposition-params", []}
     ],
     [
       {"text", "plain", [{"Content-type", "text/plain"}],
        [{"content-type-params", []}, {"disposition", "inline"}, {"disposition-params", []}],
        "This is the plain text body\r\n"},
       {"text", "html", [{"Content-type", "text/html"}],
        [{"content-type-params", []}, {"disposition", "inline"}, {"disposition-params", []}],
        "<div>This is the html body</div>\r\n"}
     ]}
  end
end
