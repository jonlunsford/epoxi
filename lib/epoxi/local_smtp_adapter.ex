defmodule Epoxi.LocalSmtpAdapter do
  @moduledoc """
  Delivers mail to external SMTP servers
  """

  alias Epoxi.SmtpConfig

  @doc """
  Sends an email and blocks until a response is received. Returns an error tuple
  or a binary that is the send receipt returned from the receiving server
  """
  @spec send_blocking(config :: Struct.t(), Epoxi.Email.t(), message :: String.t()) ::
          {:ok, response :: String.t()} | {:error, reason :: String.t(), response :: String.t()}
  def send_blocking(config, email, message) do
    config = %SmtpConfig{
      hostname: "localhost",
      relay: "localhost",
      port: config.port,
      auth: :never
    }

    Epoxi.ExternalSmtpAdapter.send_blocking(config, email, message)
  end
end
