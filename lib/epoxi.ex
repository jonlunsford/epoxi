defmodule Epoxi do
  require Logger

  @moduledoc """
  Epoxi - A complete mail server

  Epoxi is an Elixir OTP-based Mail Transfer Agent (MTA) and Mail Delivery Agent (MDA)
  designed for high-volume, fault-tolerant email delivery.
  """

  alias Epoxi.{Email, Context, SmtpClient}

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
  @spec send(Email.t(), Context.t() | nil) :: {:ok, binary()} | {:error, term()}
  def send(%Email{} = email, context \\ nil) do
    context = context || get_default_context()

    SmtpClient.send_blocking(email, context)
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
  @spec send_async(Email.t(), Context.t() | nil, (term() -> any()) | nil) :: :ok
  def send_async(%Email{} = email, context \\ nil, callback \\ &default_callback/1) do
    context = context || get_default_context()

    SmtpClient.send_async(email, context, callback)
  end

  @doc """
  Sends multiple emails in bulk using a persistent connection when possible.

  ## Examples

      emails = [%Epoxi.Email{}, %Epoxi.Email{}]
      Epoxi.send_bulk(emails)
      {:ok, :all_queued}

  """
  @spec send_bulk([Email.t()], Context.t() | nil) :: {:ok, :all_queued} | {:error, term()}
  def send_bulk(emails, context \\ nil) when is_list(emails) do
    context = context || get_default_context()

    SmtpClient.send_bulk(emails, context)
  end

  # Private functions

  defp get_default_context do
    Epoxi.Context.new()
  end

  defp default_callback({:ok, receipt}) do
    Logger.debug("Email sent successfully: #{inspect(receipt)}")
  end

  defp default_callback({:error, type, message}) do
    Logger.error("Failed to send email: #{inspect(type)} - #{inspect(message)}")
  end
end
