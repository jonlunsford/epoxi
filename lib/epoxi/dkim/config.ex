defmodule Epoxi.DKIM.Config do
  @moduledoc """
  Represents DKIM configuration for a tenant.

  Contains domain, selector, private key, and signing parameters
  for DKIM email authentication.
  """

  @type status :: :active | :inactive

  @type t :: %__MODULE__{
          tenant_id: String.t(),
          domain: String.t(),
          selector: String.t(),
          private_key_encrypted: binary(),
          algorithm: String.t(),
          canonicalization: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: status()
        }

  defstruct [
    :tenant_id,
    :domain,
    :selector,
    :private_key_encrypted,
    :algorithm,
    :canonicalization,
    :created_at,
    :updated_at,
    :status
  ]

  @valid_algorithms ["rsa-sha256", "rsa-sha1"]
  @valid_canonicalizations [
    "relaxed/relaxed",
    "relaxed/simple",
    "simple/relaxed",
    "simple/simple"
  ]

  @doc """
  Creates a new DKIM configuration with validation.

  ## Parameters

    * `attrs` - Map containing DKIM configuration attributes

  ## Examples

      iex> attrs = %{
      ...>   tenant_id: "tenant1",
      ...>   domain: "example.com",
      ...>   selector: "default",
      ...>   private_key: "-----BEGIN RSA PRIVATE KEY-----\\n..."
      ...> }
      iex> Epoxi.DKIM.Config.new(attrs)
      {:ok, %Epoxi.DKIM.Config{}}
  """
  @spec new(map()) :: {:ok, t()} | {:error, atom()}
  def new(attrs) when is_map(attrs) do
    with {:ok, tenant_id} <- validate_tenant_id(attrs[:tenant_id]),
         {:ok, domain} <- validate_domain(attrs[:domain]),
         {:ok, selector} <- validate_selector(attrs[:selector]),
         {:ok, private_key} <- validate_private_key(attrs[:private_key]),
         {:ok, algorithm} <- validate_algorithm(attrs[:algorithm] || "rsa-sha256"),
         {:ok, canonicalization} <-
           validate_canonicalization(attrs[:canonicalization] || "relaxed/relaxed"),
         {:ok, status} <- validate_status(attrs[:status] || :active) do
      now = DateTime.utc_now()

      config = %__MODULE__{
        tenant_id: tenant_id,
        domain: domain,
        selector: selector,
        private_key_encrypted: encrypt_private_key(private_key, tenant_id),
        algorithm: algorithm,
        canonicalization: canonicalization,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: status
      }

      {:ok, config}
    end
  end

  @doc """
  Updates a DKIM configuration with new attributes.

  ## Parameters

    * `config` - Existing DKIM configuration struct
    * `attrs` - Map containing attributes to update
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, atom()}
  def update(%__MODULE__{} = config, attrs) when is_map(attrs) do
    with {:ok, domain} <- validate_domain(attrs[:domain] || config.domain),
         {:ok, selector} <- validate_selector(attrs[:selector] || config.selector),
         {:ok, algorithm} <- validate_algorithm(attrs[:algorithm] || config.algorithm),
         {:ok, canonicalization} <-
           validate_canonicalization(attrs[:canonicalization] || config.canonicalization),
         {:ok, status} <- validate_status(attrs[:status] || config.status),
         {:ok, private_key_encrypted} <- get_updated_private_key(attrs[:private_key], config) do
      updated_config = %{
        config
        | domain: domain,
          selector: selector,
          private_key_encrypted: private_key_encrypted,
          algorithm: algorithm,
          canonicalization: canonicalization,
          status: status,
          updated_at: DateTime.utc_now()
      }

      {:ok, updated_config}
    end
  end

  @doc """
  Decrypts the private key for use in DKIM signing.

  ## Parameters

    * `config` - DKIM configuration struct

  ## Returns

    * `{:ok, private_key}` - Decrypted private key as string
    * `{:error, reason}` - Decryption failed
  """
  @spec decrypt_private_key(t()) :: {:ok, String.t()} | {:error, atom()}
  def decrypt_private_key(%__MODULE__{} = config) do
    decrypt_private_key(config.private_key_encrypted, config.tenant_id)
  end

  @spec get_updated_private_key(String.t() | nil, t()) :: {:ok, binary()} | {:error, atom()}
  defp get_updated_private_key(nil, config), do: {:ok, config.private_key_encrypted}

  defp get_updated_private_key(new_key, config) do
    case validate_private_key(new_key) do
      {:ok, validated_key} -> {:ok, encrypt_private_key(validated_key, config.tenant_id)}
      {:error, _} = error -> error
    end
  end

  @spec validate_tenant_id(any()) :: {:ok, String.t()} | {:error, :invalid_tenant_id}
  defp validate_tenant_id(tenant_id) when is_binary(tenant_id) and byte_size(tenant_id) > 0 do
    if String.match?(tenant_id, ~r/^[a-zA-Z0-9_-]+$/) do
      {:ok, tenant_id}
    else
      {:error, :invalid_tenant_id}
    end
  end

  defp validate_tenant_id(_), do: {:error, :invalid_tenant_id}

  @spec validate_domain(any()) :: {:ok, String.t()} | {:error, :invalid_domain}
  defp validate_domain(domain) when is_binary(domain) do
    if valid_domain?(domain) do
      {:ok, String.downcase(domain)}
    else
      {:error, :invalid_domain}
    end
  end

  defp validate_domain(_), do: {:error, :invalid_domain}

  @spec validate_selector(any()) :: {:ok, String.t()} | {:error, :invalid_selector}
  defp validate_selector(selector) when is_binary(selector) and byte_size(selector) > 0 do
    # DKIM selector must be alphanumeric, dots, hyphens, underscores
    # Must not start or end with special characters
    if String.match?(selector, ~r/^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$/) and
         byte_size(selector) <= 63 do
      {:ok, selector}
    else
      {:error, :invalid_selector}
    end
  end

  defp validate_selector(_), do: {:error, :invalid_selector}

  @spec validate_private_key(any()) :: {:ok, String.t()} | {:error, :invalid_private_key}
  defp validate_private_key(key) when is_binary(key) do
    # Basic validation for RSA private key format
    if String.contains?(key, "-----BEGIN") and String.contains?(key, "-----END") do
      {:ok, String.trim(key)}
    else
      {:error, :invalid_private_key}
    end
  end

  defp validate_private_key(_), do: {:error, :invalid_private_key}

  @spec validate_algorithm(any()) :: {:ok, String.t()} | {:error, :invalid_algorithm}
  defp validate_algorithm(algorithm) when algorithm in @valid_algorithms do
    {:ok, algorithm}
  end

  defp validate_algorithm(_), do: {:error, :invalid_algorithm}

  @spec validate_canonicalization(any()) ::
          {:ok, String.t()} | {:error, :invalid_canonicalization}
  defp validate_canonicalization(canonicalization)
       when canonicalization in @valid_canonicalizations do
    {:ok, canonicalization}
  end

  defp validate_canonicalization(_), do: {:error, :invalid_canonicalization}

  @spec validate_status(any()) :: {:ok, status()} | {:error, :invalid_status}
  defp validate_status(status) when status in [:active, :inactive] do
    {:ok, status}
  end

  defp validate_status(_), do: {:error, :invalid_status}

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

  # Encryption/Decryption functions (placeholder implementation)
  # In production, these would use proper encryption with tenant-specific keys

  @spec encrypt_private_key(String.t(), String.t()) :: binary()
  defp encrypt_private_key(private_key, tenant_id) do
    # Placeholder: In production, use AES-256 with tenant-specific salt
    # For now, just encode to prevent accidental exposure in logs
    :crypto.hash(:sha256, tenant_id <> private_key)
    |> Base.encode64()
  end

  @spec decrypt_private_key(binary(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  defp decrypt_private_key(_encrypted_key, _tenant_id) do
    # Placeholder: In production, decrypt using tenant-specific key
    # For now, return a mock private key for testing
    {:error, :decryption_not_implemented}
  end
end
