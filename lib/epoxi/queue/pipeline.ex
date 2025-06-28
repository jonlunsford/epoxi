defmodule Epoxi.Queue.Pipeline do
  @moduledoc """
  Broadway pipeline for processing queued emails.
  """

  use Broadway

  alias Epoxi.{SmtpClient, Parsing, Email}

  @default_batching [
    size: 50,
    timeout: 5000,
    concurrency: 10
  ]

  def child_spec(opts) do
    id = Keyword.get(opts, :name, __MODULE__)

    %{
      id: id,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    batching = Keyword.get(opts, :batching, @default_batching)

    broadway_opts = [
      name: name,
      producer: [
        module: {Epoxi.Queue.Producer, [poll_interval: 5_000, max_retries: 5]},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        pending: [
          batch_size: batching[:size],
          batch_timeout: batching[:timeout],
          concurrency: batching[:concurrency]
        ],
        retrying: [batch_size: 10, batch_timeout: 30_000, concurrency: 2]
      ]
    ]

    Broadway.start_link(__MODULE__, broadway_opts)
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
    {ready, not_ready} = split_retry_messages(messages)

    retried = deliver_batch(ready, batch_info)
    re_enqueued = re_enqueue_messages(not_ready)

    retried ++ re_enqueued
  end

  defp split_retry_messages(messages) do
    Enum.split_with(messages, fn message ->
      Email.time_to_retry?(message.data)
    end)
  end

  defp re_enqueue_messages(messages) do
    Enum.map(messages, fn message ->
      email = Email.handle_failure(message.data, "Trying to re-enqueue")

      message
      |> Broadway.Message.put_data(email)
      |> Broadway.Message.failed(email.status)
    end)
  end

  defp deliver_batch(messages, batch_info) do
    domain = batch_info.batch_key
    emails = Enum.map(messages, & &1.data)

    {:ok, results} = SmtpClient.send_batch(emails, domain)
    transform_delivery_results(messages, results)
  end

  defp transform_delivery_results(messages, results) do
    messages
    |> Enum.zip(results)
    |> Enum.map(&handle_delivery/1)
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
