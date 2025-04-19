defmodule Epoxi.Queue.Processor do
  @moduledoc """
  Broadway pipeline for processing queued emails
  """
  require Logger

  use Broadway
  alias Epoxi.{SmtpConfig, SmtpClient, Parsing, Email}

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
        concurrency: Keyword.get(opts, :concurrency, 1)
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        pending: [batch_size: 50, batch_timeout: 5000, concurrency: 10],
        retrying: [batch_size: 10, batch_timeout: 1000, concurrency: 2],
        failed: [batch_size: 10, batch_timeout: 1000, concurrency: 2]
      ]
    )
  end

  @impl true
  def handle_message(_processor, %Broadway.Message{data: email} = message, _context) do
    domain = Parsing.get_hostname(email.to)

    message
    |> Broadway.Message.put_batch_key(domain)
    |> Broadway.Message.put_batcher(email.status)
  end

  @impl true
  def handle_batch(:pending, messages, batch_info, _context) do
    deliver_batch(messages, batch_info)
  end

  @impl true
  def handle_batch(:retrying, messages, batch_info, _context) do
    {ready, not_ready} =
      Enum.split_with(messages, fn message ->
        Email.time_to_retry?(message.data)
      end)

    retried = deliver_batch(ready, batch_info)

    re_enqueued =
      Enum.map(not_ready, fn message ->
        message
        |> Broadway.Message.put_data(message.data)
        |> Broadway.Message.failed(:pending)
      end)

    retried ++ re_enqueued
  end

  @impl true
  def handle_batch(:failed, messages, _batch_info, _context) do
    Enum.map(messages, fn message ->
      Broadway.Message.failed(message, :complete_failure)
    end)
  end

  @impl true
  def handle_failed(messages, _context) do
    {retry, dead} =
      Enum.split_with(messages, fn message ->
        Email.retrying?(message.data)
      end)

    OffBroadwayMemory.Buffer.push(:inbox, Enum.map(retry, & &1.data))

    retry ++ dead
  end

  defp deliver_batch(messages, batch_info) do
    {:ok, socket} =
      SmtpConfig.open_socket(
        %SmtpConfig{port: 2525, relay: "localhost"},
        batch_info.batch_key
      )

    Enum.map(messages, fn message ->
      case SmtpClient.deliver_over_socket(message.data, socket) do
        {:ok, email} ->
          Broadway.Message.put_data(message, email)

        {:error, email} ->
          dbg(email)

          message
          |> Broadway.Message.put_data(email)
          |> Broadway.Message.failed(:pending)
      end
    end)
  end
end
