defmodule Epoxi do
  require Logger

  @moduledoc """
  Epoxi - A complete mail server

  Epoxi is an Elixir OTP-based Mail Transfer Agent (MTA) and Mail Delivery Agent (MDA)
  designed for high-volume, fault-tolerant email delivery.
  """

  alias Epoxi.{Email, SmtpClient}

  def start_pipeline(opts) do
    Epoxi.PipelineSupervisor.start_child({Epoxi.Queue.Pipeline, opts})
  end

  @doc """
  Sends an email synchronously and returns the result.

  ## Examples

      Epoxi.send(%Epoxi.Email{
        from: "sender@example.com",
        to: ["recipient@example.com"],
        subject: "Hello from Epoxi",
        html: "<p>This is a test email</p>",
        text: "This is a test email"
      })
      {:ok, receipt}

  """
  @spec send(Email.t(), opts :: Keyword.t()) :: {:ok, binary()} | {:error, term()}
  def send(%Email{} = email, opts \\ []) do
    SmtpClient.send_blocking(email, opts)
  end

  @doc """
  Sends an email asynchronously.

  ## Examples

      Epoxi.send_async(%Epoxi.Email{
        from: "sender@example.com",
        to: ["recipient@example.com"],
        subject: "Hello from Epoxi",
        html: "<p>This is a test email</p>",
        text: "This is a test email"
      })
      ok

  """
  @spec send_async(Email.t(), opts :: Keyword.t(), (term() -> any()) | nil) :: :ok
  def send_async(%Email{} = email, opts \\ [], callback \\ &default_callback/1) do
    SmtpClient.send_async(email, opts, callback)
  end

  @doc """
  Sends multiple emails in bulk using a persistent connection when possible.

  ## Examples

      emails = [%Epoxi.Email{}, %Epoxi.Email{}]
      Epoxi.send_bulk(emails)
      {:ok, :all_queued}

  """
  @spec send_bulk([Email.t()], Keyword.t()) :: {:ok, [Email.t()]} | {:error, term()}
  def send_bulk(emails, opts \\ []) when is_list(emails) do
    case SmtpClient.connect(opts) do
      {:ok, socket} ->
        SmtpClient.send_bulk(emails, socket)

      {:error, reason} ->
        Logger.error("Failed to connect: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp default_callback({:ok, receipt}) do
    Logger.debug("Email sent successfully: #{inspect(receipt)}")
  end

  defp default_callback({:error, type, message}) do
    Logger.error("Failed to send email: #{inspect(type)} - #{inspect(message)}")
  end
end
