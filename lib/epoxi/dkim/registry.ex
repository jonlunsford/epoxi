defmodule Epoxi.DKIM.Registry do
  @moduledoc """
  Registry for managing DKIM configurations.

  Provides fast lookup of DKIM configs by domain using ETS storage.
  Supports multiple DKIM configurations per tenant and domain.
  """

  use GenServer
  require Logger

  alias Epoxi.DKIM.Config

  @table_name :dkim_configs
  @type domain :: String.t()
  @type tenant_id :: String.t()

  @doc """
  Starts the DKIM Registry.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a DKIM configuration.

  ## Examples

      iex> config = %Epoxi.DKIM.Config{domain: "example.com", ...}
      iex> Epoxi.DKIM.Registry.register(config)
      :ok
  """
  @spec register(Config.t()) :: :ok | {:error, term()}
  def register(%Config{} = config) do
    GenServer.call(__MODULE__, {:register, config})
  end

  @doc """
  Looks up a DKIM configuration by domain.

  Returns the active DKIM config for the given domain, or nil if not found.

  ## Examples

      iex> Epoxi.DKIM.Registry.lookup("example.com")
      {:ok, %Epoxi.DKIM.Config{}}

      iex> Epoxi.DKIM.Registry.lookup("unknown.com")
      {:error, :not_found}
  """
  @spec lookup(domain()) :: {:ok, Config.t()} | {:error, :not_found}
  def lookup(domain) when is_binary(domain) do
    normalized_domain = String.downcase(domain)

    case :ets.lookup(@table_name, normalized_domain) do
      [{^normalized_domain, config}] ->
        if config.status == :active do
          {:ok, config}
        else
          {:error, :not_found}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Looks up DKIM configurations by tenant ID.

  Returns all DKIM configs for the given tenant.

  ## Examples

      iex> Epoxi.DKIM.Registry.lookup_by_tenant("tenant1")
      {:ok, [%Epoxi.DKIM.Config{}, ...]}
  """
  @spec lookup_by_tenant(tenant_id()) :: {:ok, [Config.t()]}
  def lookup_by_tenant(tenant_id) when is_binary(tenant_id) do
    configs =
      :ets.tab2list(@table_name)
      |> Enum.filter(fn {_domain, config} -> config.tenant_id == tenant_id end)
      |> Enum.map(fn {_domain, config} -> config end)

    {:ok, configs}
  end

  @doc """
  Removes a DKIM configuration by domain.

  ## Examples

      iex> Epoxi.DKIM.Registry.remove("example.com")
      :ok
  """
  @spec remove(domain()) :: :ok
  def remove(domain) when is_binary(domain) do
    GenServer.call(__MODULE__, {:remove, String.downcase(domain)})
  end

  @doc """
  Updates an existing DKIM configuration.

  ## Examples

      iex> updated_config = %Epoxi.DKIM.Config{domain: "example.com", ...}
      iex> Epoxi.DKIM.Registry.update(updated_config)
      :ok
  """
  @spec update(Config.t()) :: :ok | {:error, term()}
  def update(%Config{} = config) do
    GenServer.call(__MODULE__, {:update, config})
  end

  @doc """
  Lists all DKIM configurations.

  ## Examples

      iex> Epoxi.DKIM.Registry.list()
      [%Epoxi.DKIM.Config{}, ...]
  """
  @spec list() :: [Config.t()]
  def list do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {_domain, config} -> config end)
  end

  @doc """
  Clears all DKIM configurations. Primarily for testing.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @impl true
  def init(_opts) do
    table =
      :ets.new(@table_name, [
        :named_table,
        :set,
        :public,
        read_concurrency: true
      ])

    Logger.info("DKIM Registry started with table: #{inspect(table)}")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register, %Config{} = config}, _from, state) do
    normalized_domain = String.downcase(config.domain)

    case :ets.lookup(@table_name, normalized_domain) do
      [] ->
        :ets.insert(@table_name, {normalized_domain, config})
        Logger.debug("Registered DKIM config for domain: #{normalized_domain}")
        {:reply, :ok, state}

      [{^normalized_domain, _existing}] ->
        Logger.warning(
          "DKIM config already exists for domain: #{normalized_domain}. Use update/1 instead."
        )

        {:reply, {:error, :already_exists}, state}
    end
  end

  @impl true
  def handle_call({:update, %Config{} = config}, _from, state) do
    normalized_domain = String.downcase(config.domain)

    case :ets.lookup(@table_name, normalized_domain) do
      [{^normalized_domain, _existing}] ->
        :ets.insert(@table_name, {normalized_domain, config})
        Logger.debug("Updated DKIM config for domain: #{normalized_domain}")
        {:reply, :ok, state}

      [] ->
        Logger.warning("DKIM config not found for domain: #{normalized_domain}. Use register/1.")
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:remove, domain}, _from, state) do
    :ets.delete(@table_name, domain)
    Logger.debug("Removed DKIM config for domain: #{domain}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    Logger.debug("Cleared all DKIM configs")
    {:reply, :ok, state}
  end
end
