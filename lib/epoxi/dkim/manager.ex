defmodule Epoxi.DKIM.Manager do
  @moduledoc """
  Manages DKIM configurations and operations.

  Provides a high-level API for creating, updating, and managing
  DKIM configurations with proper validation and error handling.
  """

  alias Epoxi.DKIM.{Config, Registry}

  @type config_attrs :: %{
          tenant_id: String.t(),
          domain: String.t(),
          selector: String.t(),
          private_key: String.t(),
          algorithm: String.t() | nil,
          canonicalization: String.t() | nil,
          status: atom() | nil
        }

  @doc """
  Creates and registers a new DKIM configuration.

  ## Examples

      iex> attrs = %{tenant_id: "t1", domain: "example.com", selector: "dkim", private_key: "..."}
      iex> Epoxi.DKIM.Manager.create(attrs)
      {:ok, %Epoxi.DKIM.Config{}}

      iex> Epoxi.DKIM.Manager.create(%{})
      {:error, :invalid_tenant_id}
  """
  @spec create(map()) :: {:ok, Config.t()} | {:error, atom()}
  def create(attrs) when is_map(attrs) do
    with {:ok, config} <- Config.new(attrs),
         :ok <- Registry.register(config) do
      {:ok, config}
    end
  end

  @doc """
  Updates an existing DKIM configuration.

  ## Examples

      iex> Epoxi.DKIM.Manager.update("example.com", %{selector: "new-selector"})
      {:ok, %Epoxi.DKIM.Config{}}

      iex> Epoxi.DKIM.Manager.update("unknown.com", %{})
      {:error, :not_found}
  """
  @spec update(String.t(), map()) :: {:ok, Config.t()} | {:error, atom()}
  def update(domain, attrs) when is_binary(domain) and is_map(attrs) do
    with {:ok, config} <- Registry.lookup(domain),
         {:ok, updated_config} <- Config.update(config, attrs),
         :ok <- Registry.update(updated_config) do
      {:ok, updated_config}
    end
  end

  @doc """
  Retrieves a DKIM configuration by domain.

  Returns only the public fields (no private key).

  ## Examples

      iex> Epoxi.DKIM.Manager.get("example.com")
      {:ok, %{domain: "example.com", ...}}
  """
  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(domain) when is_binary(domain) do
    case Registry.lookup(domain) do
      {:ok, config} -> {:ok, to_public_map(config)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Lists all DKIM configurations.

  Returns only public fields (no private keys).
  """
  @spec list() :: [map()]
  def list do
    Registry.list()
    |> Enum.map(&to_public_map/1)
  end

  @doc """
  Lists DKIM configurations for a specific tenant.

  ## Examples

      iex> Epoxi.DKIM.Manager.list_by_tenant("tenant1")
      {:ok, [%{domain: "example.com", ...}]}
  """
  @spec list_by_tenant(String.t()) :: {:ok, [map()]}
  def list_by_tenant(tenant_id) when is_binary(tenant_id) do
    {:ok, configs} = Registry.lookup_by_tenant(tenant_id)
    {:ok, Enum.map(configs, &to_public_map/1)}
  end

  @doc """
  Removes a DKIM configuration by domain.

  ## Examples

      iex> Epoxi.DKIM.Manager.remove("example.com")
      :ok
  """
  @spec remove(String.t()) :: :ok
  def remove(domain) when is_binary(domain) do
    Registry.remove(domain)
  end

  @spec to_public_map(Config.t()) :: map()
  defp to_public_map(config) do
    %{
      tenant_id: config.tenant_id,
      domain: config.domain,
      selector: config.selector,
      algorithm: config.algorithm,
      canonicalization: config.canonicalization,
      status: config.status,
      created_at: config.created_at,
      updated_at: config.updated_at
    }
  end
end
