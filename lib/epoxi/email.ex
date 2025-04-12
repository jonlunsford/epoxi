defmodule Epoxi.Email do
  @moduledoc """
  Struct representing an email message.
  """

  alias Epoxi.Email

  defstruct subject: "",
            from: "",
            reply_to: "",
            to: [],
            cc: [],
            bcc: [],
            attachments: [],
            data: %{},
            html: "",
            text: "",
            delivery: nil,
            log: [],
            content_type: nil,
            headers: %{}

  @type t :: %__MODULE__{
          subject: String.t(),
          from: String.t(),
          reply_to: String.t(),
          to: List.t(),
          cc: List.t(),
          bcc: List.t(),
          attachments: List.t(),
          data: Map.t(),
          html: String.t(),
          text: String.t(),
          delivery: DateTime.t(),
          log: [log_entry()],
          content_type: String.t(),
          headers: Map.t()
        }

  @type log_entry :: %{
          :timestamp => DateTime.t(),
          :message => term()
        }

  def put_content_type(%Email{html: h, text: ""} = email) when is_bitstring(h) do
    %{email | content_type: "text/html"}
  end

  def put_content_type(%Email{html: "", text: t} = email) when is_bitstring(t) do
    %{email | content_type: "text/plain"}
  end

  def put_content_type(%Email{html: h, text: t} = email)
      when is_bitstring(t) and is_bitstring(h) do
    %{email | content_type: "multipart/mixed"}
  end

  def put_content_type(email) do
    %{email | content_type: "multipart/alternative"}
  end

  def put_log_entry(%Email{} = email, entry) do
    entry = %{
      timestamp: DateTime.utc_now(),
      message: entry
    }

    %{email | log: [entry | email.log]}
  end
end
