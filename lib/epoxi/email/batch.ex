defmodule Epoxi.Email.Batch do
  @moduledoc """
  A module for handling email batching operations.
  """

  defstruct emails: [],
            size: 50,
            target_domain: "",
            ip: "",
            ip_pool: "",
            routing_key: nil,
            policy: nil

  @type t :: %__MODULE__{
          emails: [Epoxi.Email.t()],
          size: non_neg_integer(),
          target_domain: String.t(),
          ip: String.t(),
          ip_pool: String.t(),
          routing_key: Epoxi.Email.RoutingKey.t() | nil,
          policy: Epoxi.Queue.PipelinePolicy.t() | nil
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
    batch_size = Keyword.get(opts, :size, 50)
    mx_lookup = Keyword.get(opts, :mx_lookup, Epoxi.DNS.MxLookup)

    emails
    |> Enum.group_by(&routing_key(&1, mx_lookup))
    |> Enum.flat_map(fn {{mx_host, ip}, grouped_emails} ->
      grouped_emails
      |> Enum.chunk_every(batch_size)
      |> Enum.map(fn email_chunk ->
        routing_key = Epoxi.Email.RoutingKey.generate(mx_host, ip)
        policy = Epoxi.ProviderPolicy.for_mx_host(mx_host)

        new(
          emails: email_chunk,
          routing_key: routing_key,
          size: length(email_chunk),
          target_domain: extract_domain(hd(email_chunk)),
          policy: policy,
          ip: ip
        )
      end)
    end)
  end

  defp routing_key(%Epoxi.Email{to: to, delivery: delivery}, mx_lookup) do
    domain = Epoxi.Parsing.get_hostname(to)
    mx_host = get_mx_host(domain, mx_lookup)
    {mx_host, delivery[:ip]}
  end

  defp get_mx_host(domain, mx_lookup) do
    case mx_lookup.lookup(domain) do
      [first_record | _rest] ->
        {_priority, relay} = first_record
        String.Chars.to_string(relay)

      [] ->
        domain
    end
  end

  defp extract_domain(%Epoxi.Email{to: to}) do
    Epoxi.Parsing.get_hostname(to)
  end
end
