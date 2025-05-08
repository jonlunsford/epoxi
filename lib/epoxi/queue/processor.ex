defmodule Epoxi.Queue.Processor do
  @moduledoc """
  Broadway pipeline for processing queued emails.

  ## Dynamic Creation

  This processor can be dynamically created and supervised using `Epoxi.Queue.ProcessorSupervisor`.
  Multiple processors can be created with different configurations to handle various queues
  or email processing strategies.

  ### Starting a processor dynamically

  ```elixir
  # Start the supervisor (typically in your application supervision tree)
  Epoxi.Queue.ProcessorSupervisor.start_link()

  # Start a new processor with a unique ID
  Epoxi.Queue.ProcessorSupervisor.start_processor(
    id: :promotional_emails,
    producer_module: Broadway.DummyProducer,
    producer_options: [queue_name: "promotional"]
  )

  # Start another processor with different settings
  Epoxi.Queue.ProcessorSupervisor.start_processor(
    id: :transactional_emails,
    producer_module: Broadway.DummyProducer,
    producer_options: [queue_name: "transactional"],
    processor_concurrency: 4,
    pending_batch_size: 100,
    smtp_client: MyCustomSmtpClient
  )

  The processor accepts the following options:

  * `:id` - Required. Unique identifier for the processor
  * `:name` - Optional. The name to register the Broadway process (derived from ID if not provided)
  * `:producer_options` - Optional. Options to configure the producer.
  * `:smtp_client` - Optional. The SMTP client module to use (default: Epoxi.SmtpClient)
  * `:smtp_opts` - Optional. The SMTP options to configure `smtp_client` with (see: Epoxi.SmtpConfig)
  """
  require Logger

  use Broadway
  alias Epoxi.{SmtpClient, Parsing, Email}

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
    producer_opts = Keyword.get(opts, :producer_options, [])
    smtp_client = Keyword.get(opts, :smtp_client, SmtpClient)
    smtp_opts = Keyword.get(opts, :smtp_opts, [])

    broadway_opts = [
      name: name,
      producer: producer_opts,
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        pending: [batch_size: 50, batch_timeout: 5000, concurrency: 10],
        retrying: [batch_size: 10, batch_timeout: 1000, concurrency: 2]
      ],
      context: %{
        smtp_client: smtp_client,
        smtp_opts: smtp_opts
      }
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
  def handle_batch(:pending, messages, batch_info, context) do
    deliver_batch(messages, batch_info, context)
  end

  @impl true
  def handle_batch(:retrying, messages, batch_info, context) do
    {ready, not_ready} = split_retry_messages(messages)

    retried = deliver_batch(ready, batch_info, context)
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

  defp deliver_batch(messages, batch_info, context) do
    domain = batch_info.batch_key
    emails = Enum.map(messages, & &1.data)
    smtp_client = Map.get(context, :smtp_client, SmtpClient)

    smtp_opts =
      context
      |> Map.get(:smtp_opts, [])
      |> Keyword.put_new(:relay, domain)
      |> Keyword.put_new(:hostname, domain)

    case send_emails(emails, smtp_client, smtp_opts) do
      {:ok, results} ->
        transform_delivery_results(messages, results)

      {:error, reason} ->
        failed_emails = mark_emails_as_failed(emails, reason)
        transform_delivery_results(messages, failed_emails)
    end
  end

  defp send_emails(emails, smtp_client, smtp_opts) do
    with {:ok, socket} <- smtp_client.connect(smtp_opts),
         {:ok, results} <- smtp_client.send_bulk(emails, socket),
         :ok <- smtp_client.disconnect(socket) do
      {:ok, results}
    else
      error -> error
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
    dbg(email)
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
