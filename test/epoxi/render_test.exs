defmodule Epox.RenderTest do
  use ExUnit.Case, async: true

  alias Epoxi.Email
  alias Epoxi.Render

  describe "encode/1" do
    test "it returns a string" do
      email = %Email{
        subject: "Test Subject",
        from: "Senders Name <from@test.com>",
        reply_to: "no-reply@test.com",
        to: ["Recipient Name <to@test.com>"],
        cc: [],
        bcc: [],
        attachments: [],
        data: %{},
        html: "<div>This is the html body</div>",
        text: "This is the plain text body"
      }

      assert is_bitstring(Render.encode(email))
    end

    test "it compiles EEx" do
      email = %Email{
        subject: "Test Subject",
        from: "Senders Name <from@test.com>",
        reply_to: "no-reply@test.com",
        to: ["Recipient Name <to@test.com>"],
        data: [first_name: "foo"],
        html: "<div>Hello <%= first_name %></div>",
        text: "Hello <%= first_name %>"
      }

      result = Render.encode(email)

      assert result =~ "<div>Hello foo</div>"
    end
  end

  describe "headers_for/1" do
    test "returns a list of tuples for the email" do
      email = %Email{
        from: "test@from.com",
        to: ["test@to.com", "bar@biz.com", "Hello <biz@baz.com>"],
        reply_to: "no-reply@test.com",
        cc: ["cc1@test.com", "cc2@test.com"],
        bcc: ["bcc1@test.com", "bcc2@test.com"],
        subject: "foo",
        headers: %{
          "X-Custom-header": "custom_value",
          "X-Custom-foo": "custom_bar"
        }
      }

      headers = Render.headers_for(email)

      assert [
        {"From", "Test <test@from.com>"},
        {"To", "Test <test@to.com>, Bar <bar@biz.com>, Hello <biz@baz.com>"},
        {"Subject", "foo"},
        {"reply-to", "no-reply@test.com"},
        {"Cc", "Cc1 <cc1@test.com>, Cc2 <cc2@test.com>"},
        {"Bcc", "Bcc1 <bcc1@test.com>, Bcc2 <bcc2@test.com>"},
        {"X-Custom-header", "custom_value"},
        {"X-Custom-foo", "custom_bar"}
      ] = headers
    end

    test "rejects blank, nil, or empty headers" do
      email = %Email{
        from: "test@from.com",
        to: ["test@to.com"],
        subject: "foo"
      }

      headers = Render.headers_for(email)

      assert [
        {"From", "Test <test@from.com>"},
        {"To", "Test <test@to.com>"},
        {"Subject", "foo"}
      ] = headers
    end
  end

  test "render/1 returns a valid mimemail struct" do
    email = %Email{
      subject: "Test Subject",
      from: "Senders Name <from@test.com>",
      reply_to: "no-reply@test.com",
      to: ["Recipient Name <to@test.com>"],
      cc: [],
      bcc: [],
      attachments: [],
      data: %{},
      html: "<div>This is the html body</div>",
      text: "This is the plain text body"
    }

    {type, subtype, headers, params, bodies} = Render.render(email)

    assert type == "multipart"
    assert subtype == "mixed"
    assert [
      {"From", "Senders Name <from@test.com>"},
      {"To", "Recipient Name <to@test.com>"},
      {"Subject", "Test Subject"},
      {"reply-to", "no-reply@test.com"}
    ] = headers

    assert %{
      "transfer-encoding": "quoted-printable",
      "content-type-params": [],
      disposition: "inline",
      "disposition-params": []
    } = params

    assert [
      {"text", "plain",
        [
          {"Content-type", "text/plain"}
        ],
        %{
          "transfer-encoding": "quoted-printable",
          "content-type-params": [],
          disposition: "inline",
          "disposition-params": []
        },
      "This is the plain text body"},
      {"text", "html",
        [
          {"Content-type", "text/html"}
        ],
        %{
          "transfer-encoding": "quoted-printable",
          "content-type-params": [],
          disposition: "inline",
          "disposition-params": []
        },
      "<div>This is the html body</div>"}
    ] = bodies
  end
end
