defmodule Epoxi.Email.Batch do
  @moduledoc """
  A module for handling email batching operations.
  """

  defstruct emails: [],
            size: 50,
            target_domain: "",
            ip: "",
            ip_pool: ""

  @type t :: %__MODULE__{
          emails: [Epoxi.Email.t()],
          size: non_neg_integer(),
          target_domain: String.t(),
          ip: String.t(),
          ip_pool: String.t()
        }

  def new(opts \\ []) do
    struct(Epoxi.Email.Batch, opts)
  end

  @doc """
  Creates batches from a list of emails, grouping by target domain and IP.

  Emails are grouped by their routing key (target_domain + ip) and then split
  into batches according to the default batch size (50).
  """
  def from_emails(emails) when is_list(emails) do
    from_emails(emails, size: 50)
  end

  @doc """
  Creates batches from a list of emails with custom batch size.

  ## Options

  * `:size` - Maximum number of emails per batch (default: 50)
  """
  def from_emails(emails, opts) when is_list(emails) do
    size = Keyword.get(opts, :size, 50)

    emails
    |> Enum.group_by(&routing_key/1)
    |> Enum.flat_map(fn {{domain, ip}, grouped_emails} ->
      grouped_emails
      |> Enum.chunk_every(size)
      |> Enum.map(fn email_chunk ->
        new(
          emails: email_chunk,
          size: length(email_chunk),
          target_domain: domain,
          ip: ip
        )
      end)
    end)
  end

  # Extract routing key (domain + ip) from an email
  defp routing_key(%Epoxi.Email{to: to, delivery: delivery}) do
    domain = Epoxi.Parsing.get_hostname(to)
    {domain, delivery[:ip]}
  end
end
