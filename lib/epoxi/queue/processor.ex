defmodule Epoxi.Queue.Processor do
  @moduledoc """
  Broadway pipeline for processing queued emails
  """
  require Logger

  use Broadway
  alias Epoxi.{SmtpClient, Parsing, Email}

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
    domain = batch_info.batch_key
    emails = Enum.map(messages, & &1.data)

    with {:ok, socket} <- SmtpClient.connect(relay: domain),
         {:ok, results} <- SmtpClient.send_bulk(emails, socket),
         :ok <- SmtpClient.disconnect(socket) do
      messages
      |> Enum.zip(results)
      |> Enum.map(&handle_delivery/1)
    else
      {:error, reason} ->
        Logger.error("Failed to process batch for domain #{domain}: #{inspect(reason)}")
        Enum.map(messages, &Broadway.Message.failed(&1, reason))
    end
  end

  defp handle_delivery({message, %Email{status: :delivered} = email}) do
    message
    |> Broadway.Message.put_data(email)
  end

  defp handle_delivery({message, %Email{status: status} = email}) do
    message
    |> Broadway.Message.put_data(email)
    |> Broadway.Message.failed(status)
  end
end
