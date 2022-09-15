defmodule Epoxi.Adapters.SMTP do
  @moduledoc """
  Delivers mail to SMTP servers
  """

  alias Epoxi.SmtpConfig

  @doc """
  Sends an email and blocks until a response is received. Returns an error tuple
  or a binary that is the send receipt returned from the receiving server
  """
  @spec send_blocking(SmtpConfig.t(), Epoxi.Email.t(), message :: String.t()) ::
          {:ok, response :: String.t()} | {:error, reason :: String.t(), response :: String.t()}
  def send_blocking(%SmtpConfig{} = config, email, message) do
    config = Map.to_list(config)

    response = :gen_smtp_client.send_blocking({email.from, email.to, message}, config)

    case response do
      {:error, _, reason} -> {:error, reason, response}
      {:error, reason} -> {:error, reason, response}
      _ -> {:ok, response}
    end
  end
end
