defmodule Epoxi.Email do
  @moduledoc """
  Struct representing an email message.
  """

  @max_retries 5
  # 5min, 30min, 2hr, 4hr, 8hr
  @retry_intervals [5 * 60, 30 * 60, 2 * 60 * 60, 4 * 60 * 60, 8 * 60 * 60]

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
            updated_at: nil,
            delivered_at: nil,
            next_retry_at: nil,
            retry_count: 0,
            status: :pending,
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
          updated_at: DateTime.t(),
          delivered_at: DateTime.t(),
          next_retry_at: DateTime.t(),
          retry_count: non_neg_integer(),
          status: atom(),
          log: [log_entry()],
          content_type: String.t(),
          headers: Map.t()
        }

  @type log_entry :: %{
          :timestamp => DateTime.t(),
          :message => term()
        }

  def handle_failure(
        %Email{retry_count: @max_retries} = email,
        {:temporary_failure, _reason} = failure
      ) do
    dbg("Max retries reached")
    dbg(email)

    email
    |> put_log_entry(failure)
    |> put_log_entry("Max retries reached")
    |> update(%{status: :failed})
  end

  def handle_failure(
        %Email{retry_count: retry_count} = email,
        {:temporary_failure, _reason} = failure
      ) do
    email
    |> put_log_entry(failure)
    |> put_next_retry()
    |> update(%{status: :retrying, retry_count: retry_count + 1})
  end

  def handle_failure(%Email{} = email, reason) do
    email
    |> put_log_entry(reason)
    |> update(%{status: :failed})
  end

  def handle_delivery(%Email{} = email, receipt) do
    email
    |> put_log_entry(receipt)
    |> update(%{status: :delivered, delivered_at: DateTime.utc_now()})
  end

  def update(%Email{} = email, attrs) when is_map(attrs) do
    email
    |> Map.merge(attrs)
    |> Map.update!(:updated_at, fn _ -> DateTime.utc_now() end)
  end

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

  def put_next_retry(%Email{retry_count: retry_count} = email) do
    now = DateTime.utc_now()
    retry_seconds = Enum.at(@retry_intervals, retry_count, hd(@retry_intervals))
    next_retry_at = DateTime.add(now, retry_seconds)

    email
    |> update(%{next_retry_at: next_retry_at})
  end

  def retrying?(%Email{status: :retrying}), do: true
  def retrying?(%Email{status: status}) when status in [:pending, :failed], do: false

  def time_to_retry?(%Email{retry_count: @max_retries}), do: false
  def time_to_retry?(%Email{status: status}) when status in [:failed, :pending], do: false

  def time_to_retry?(%Email{status: :retrying} = email) do
    true
    # case email.next_retry_at do
    #   nil ->
    #     true
    #
    #   next_retry_at ->
    #     DateTime.compare(DateTime.utc_now(), next_retry_at) == :gt
    # end
  end
end
