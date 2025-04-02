defmodule Epoxi.Queue.Processor do
  @moduledoc """
  Broadway pipeline for processing queued emails
  """

  use Broadway

  alias Epoxi.{SmtpClient, Queue}

  # @max_retries 3
  # 5min, 30min, 2hr
  # @retry_intervals [5 * 60, 30 * 60, 2 * 60 * 60]

  def start_link(opts) do
    producer_module = Application.fetch_env!(:epoxi, :producer_module)
    producer_options = Application.get_env(:epoxi, :producer_options, [])

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {producer_module, producer_options},
        transformer: {__MODULE__, :transform, []},
        concurrency: Keyword.get(opts, :concurrency, 1)
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        default: [batch_size: 10, batch_timeout: 1000, concurrency: 5],
        retry: [batch_size: 10, batch_timeout: 1000, concurrency: 2],
        failed: [batch_size: 10, batch_timeout: 1000, concurrency: 2]
      ]
    )
  end

  def transform(message, _opts) do
    %Broadway.Message{
      data: message,
      acknowledger: {__MODULE__, :ack_id, message.id}
    }
  end

  @impl true
  def handle_message(_processor, %Broadway.Message{data: data} = message, _context) do
    # Try to send the email
    result = SmtpClient.send_blocking(data.email, data.context)

    case result do
      {:ok, receipt} ->
        Broadway.Message.update_data(
          message,
          &Queue.Message.mark_delivered(&1, receipt)
        )

      {:error, reason} ->
        Broadway.Message.update_data(
          message,
          &Queue.Message.mark_failed(&1, reason)
        )
    end
  end

  @impl true
  def handle_batch(_batcher, messages, _batch_info, _context) do
    messages
  end

  def ack_id(_, _, _), do: :ok
end
