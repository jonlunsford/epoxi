defmodule Epoxi.Tenant do
  @moduledoc """
  Represents a tenant configuration in the Epoxi mail system.

  A tenant is an entity that can have multiple domains and their own
  DKIM configuration for email authentication.
  """

  @type status :: :active | :inactive | :suspended

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          domains: [String.t()],
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: status(),
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :domains,
    :created_at,
    :updated_at,
    :status,
    :metadata
  ]

  @doc """
  Creates a new tenant with validation.

  ## Parameters

    * `attrs` - Map containing tenant attributes

  ## Examples

      iex> Epoxi.Tenant.new(%{id: "tenant1", name: "Test Tenant", domains: ["example.com"]})
      {:ok, %Epoxi.Tenant{id: "tenant1", name: "Test Tenant", domains: ["example.com"]}}

      iex> Epoxi.Tenant.new(%{})
      {:error, :invalid_id}
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom()}
  def new(attrs) when is_map(attrs) do
    with {:ok, id} <- validate_id(attrs[:id]),
         {:ok, name} <- validate_name(attrs[:name]),
         {:ok, domains} <- validate_domains(attrs[:domains]),
         {:ok, status} <- validate_status(attrs[:status] || :active),
         {:ok, metadata} <- validate_metadata(attrs[:metadata] || %{}) do
      now = DateTime.utc_now()

      tenant = %__MODULE__{
        id: id,
        name: name,
        domains: domains,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: status,
        metadata: metadata
      }

      {:ok, tenant}
    end
  end

  @doc """
  Updates a tenant with new attributes.

  ## Parameters

    * `tenant` - Existing tenant struct
    * `attrs` - Map containing attributes to update

  ## Examples

      iex> tenant = %Epoxi.Tenant{id: "tenant1", name: "Old Name", domains: ["old.com"]}
      iex> Epoxi.Tenant.update(tenant, %{name: "New Name"})
      {:ok, %Epoxi.Tenant{name: "New Name"}}
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, atom()}
  def update(%__MODULE__{} = tenant, attrs) when is_map(attrs) do
    with {:ok, name} <- validate_name(attrs[:name] || tenant.name),
         {:ok, domains} <- validate_domains(attrs[:domains] || tenant.domains),
         {:ok, status} <- validate_status(attrs[:status] || tenant.status),
         {:ok, metadata} <- validate_metadata(attrs[:metadata] || tenant.metadata) do
      updated_tenant = %{
        tenant
        | name: name,
          domains: domains,
          status: status,
          metadata: metadata,
          updated_at: DateTime.utc_now()
      }

      {:ok, updated_tenant}
    end
  end

  # Private validation functions

  @spec validate_id(any()) :: {:ok, String.t()} | {:error, :invalid_id}
  defp validate_id(id) when is_binary(id) and byte_size(id) > 0 do
    if String.match?(id, ~r/^[a-zA-Z0-9_-]+$/) do
      {:ok, id}
    else
      {:error, :invalid_id}
    end
  end

  defp validate_id(_), do: {:error, :invalid_id}

  @spec validate_name(any()) :: {:ok, String.t()} | {:error, :invalid_name}
  defp validate_name(name) when is_binary(name) and byte_size(name) > 0 do
    if byte_size(name) <= 255 do
      {:ok, String.trim(name)}
    else
      {:error, :invalid_name}
    end
  end

  defp validate_name(_), do: {:error, :invalid_name}

  @spec validate_domains(any()) :: {:ok, [String.t()]} | {:error, :invalid_domains}
  defp validate_domains(domains) when is_list(domains) and length(domains) > 0 do
    if Enum.all?(domains, &valid_domain?/1) do
      {:ok, Enum.map(domains, &String.downcase/1)}
    else
      {:error, :invalid_domains}
    end
  end

  defp validate_domains(_), do: {:error, :invalid_domains}

  @spec validate_status(any()) :: {:ok, status()} | {:error, :invalid_status}
  defp validate_status(status) when status in [:active, :inactive, :suspended] do
    {:ok, status}
  end

  defp validate_status(_), do: {:error, :invalid_status}

  @spec validate_metadata(any()) :: {:ok, map()} | {:error, :invalid_metadata}
  defp validate_metadata(metadata) when is_map(metadata) do
    {:ok, metadata}
  end

  defp validate_metadata(_), do: {:error, :invalid_metadata}

  @spec valid_domain?(String.t()) :: boolean()
  defp valid_domain?(domain) when is_binary(domain) do
    # Basic domain validation - alphanumeric, dots, hyphens
    # Must not start or end with hyphen or dot
    # Must contain at least one dot
    # Must not be an IP address
    String.match?(
      domain,
      ~r/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$/
    ) and
      not ip_address?(domain)
  end

  @spec ip_address?(String.t()) :: boolean()
  defp ip_address?(domain) do
    # Check if it looks like an IPv4 address (all numeric parts)
    parts = String.split(domain, ".")

    length(parts) == 4 and
      Enum.all?(parts, fn part ->
        case Integer.parse(part) do
          {num, ""} when num >= 0 and num <= 255 -> true
          _ -> false
        end
      end)
  end
end
