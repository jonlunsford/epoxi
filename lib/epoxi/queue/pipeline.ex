defmodule Epoxi.Queue.Pipeline do
  @moduledoc """
  Broadway pipeline for processing queued emails.
  """

  use Broadway

  alias Epoxi.{SmtpClient, Parsing, Email}
  alias Epoxi.Queue.PipelinePolicy

  def build_policy_opts(%PipelinePolicy{} = policy) do
    [
      name: policy.name,
      producer: [
        module:
          {Epoxi.Queue.Producer,
           [poll_interval: policy.batch_timeout, max_retries: policy.max_retries]},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        pending: [
          batch_size: policy.batch_size,
          batch_timeout: policy.batch_timeout,
          concurrency: policy.max_connections
        ],
        retrying: [
          batch_size: PipelinePolicy.retry_batch_size(policy),
          batch_timeout: PipelinePolicy.retry_batch_timeout(policy),
          concurrency: PipelinePolicy.retry_max_connections(policy)
        ]
      ]
    ]
  end

  def child_spec(opts) do
    id = Keyword.get(opts, :name, __MODULE__)

    %{
      id: id,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 30_000
    }
  end

  def start_link(opts) do
    Broadway.start_link(__MODULE__, opts)
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
      email = mark_email_as_failed(message.data, "Trying to re-enqueue")

      message
      |> Broadway.Message.put_data(email)
      |> Broadway.Message.failed(email.status)
    end)
  end

  defp deliver_batch(messages, batch_info) do
    domain = batch_info.batch_key
    emails = Enum.map(messages, & &1.data)

    case SmtpClient.send_batch(emails, domain) do
      {:ok, results} ->
        transform_delivery_results(messages, results)

      {:error, reason} ->
        failed_emails = mark_emails_as_failed(emails, reason)
        transform_delivery_results(messages, failed_emails)
    end
  end

  defp transform_delivery_results(messages, results) do
    messages
    |> Enum.zip(results)
    |> Enum.map(&handle_delivery/1)
  end

  defp mark_emails_as_failed(emails, reason) do
    Enum.map(emails, fn email ->
      mark_email_as_failed(email, reason)
    end)
  end

  defp mark_email_as_failed(email, reason) do
    Email.handle_failure(email, reason)
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
