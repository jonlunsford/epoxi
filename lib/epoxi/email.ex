defmodule Epoxi.Email do
  @moduledoc """
  Struct representing an email message.
  """

  alias Epoxi.Email

  defstruct subject: "",
            from: "",
            reply_to: "",
            to: "",
            cc: [],
            bcc: [],
            attachments: [],
            data: %{},
            html: nil,
            text: nil,
            delivery: nil,
            content_type: nil

  def put_content_type(%Email{html: h, text: nil} = email) when is_bitstring(h) do
    %{email | content_type: "text/html"}
  end

  def put_content_type(%Email{html: nil, text: t} = email) when is_bitstring(t) do
    %{email | content_type: "text/plain"}
  end

  def put_content_type(%Email{html: h, text: t} = email)
      when is_bitstring(t) and is_bitstring(h) do
    %{email | content_type: "multipart/mixed"}
  end

  def put_content_type(email) do
    %{email | content_type: "multipart/alternative"}
  end
end
