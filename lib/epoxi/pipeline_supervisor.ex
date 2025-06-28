defmodule Epoxi.PipelineSupervisor do
  @moduledoc """
  Dynamic supervisor for managing domain+IP specific email delivery pipelines.
  
  Automatically creates and manages Broadway pipelines for each unique
  domain+IP combination with provider-specific configurations and rate limiting.
  """
  
  use DynamicSupervisor
  require Logger
  
  alias Epoxi.{Queue, ProviderPolicy}

  @registry_name :epoxi_pipeline_registry

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a pipeline for a specific domain+IP combination.
  Creates a Broadway pipeline with provider-specific rate limiting.
  """
  @spec start_pipeline_for_domain_ip(String.t(), String.t()) :: 
    DynamicSupervisor.on_start_child()
  def start_pipeline_for_domain_ip(domain, ip) do
    pipeline_id = pipeline_id(domain, ip)
    
    case Registry.lookup(@registry_name, pipeline_id) do
      [] ->
        # Pipeline doesn't exist, create it
        spec = pipeline_spec(domain, ip, pipeline_id)
        start_child(spec)
        
      [{pid, _}] ->
        # Pipeline already exists
        Logger.debug("Pipeline #{pipeline_id} already exists")
        {:ok, pid}
    end
  end

  @doc """
  Stop a pipeline for a specific domain+IP combination.
  """
  @spec stop_pipeline_for_domain_ip(String.t(), String.t()) :: :ok | {:error, :not_found}
  def stop_pipeline_for_domain_ip(domain, ip) do
    pipeline_id = pipeline_id(domain, ip)
    
    case Registry.lookup(@registry_name, pipeline_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        :ok
        
      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Get all active pipelines with their domain+IP combinations.
  """
  @spec list_active_pipelines() :: [{String.t(), String.t(), pid()}]
  def list_active_pipelines() do
    Registry.select(@registry_name, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.map(fn {pipeline_id, pid, _} ->
      {domain, ip} = parse_pipeline_id(pipeline_id)
      {domain, ip, pid}
    end)
  end

  @doc """
  Ensure a pipeline exists for the given domain+IP combination.
  Returns the pipeline name for message routing.
  """
  @spec ensure_pipeline(String.t(), String.t()) :: {:ok, atom()} | {:error, term()}
  def ensure_pipeline(domain, ip) do
    case start_pipeline_for_domain_ip(domain, ip) do
      {:ok, _pid} ->
        {:ok, pipeline_name(domain, ip)}
        
      {:error, reason} ->
        Logger.error("Failed to start pipeline for #{domain}+#{ip}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def start_child(spec) do
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(_opts) do
    # Register the pipeline registry
    Registry.start_link(keys: :unique, name: @registry_name)
    
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Private functions

  defp pipeline_spec(domain, ip, pipeline_id) do
    pipeline_name = pipeline_name(domain, ip)
    policy = ProviderPolicy.get_policy(domain)
    
    # Configure Broadway pipeline with provider-specific settings
    broadway_opts = [
      name: pipeline_name,
      producer: [
        module: {Queue.Producer, [
          poll_interval: 5_000,
          max_retries: 5,
          domain: domain,
          ip: ip
        ]},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: calculate_processor_concurrency(policy)]
      ],
      batchers: [
        pending: provider_batch_config(policy),
        retrying: [
          batch_size: 10,
          batch_timeout: 30_000,
          concurrency: 1
        ]
      ]
    ]

    %{
      id: pipeline_id,
      start: {Epoxi.Queue.Pipeline, :start_link, [[broadway_opts: broadway_opts]]},
      type: :worker,
      restart: :permanent,
      shutdown: 30_000
    }
  end

  defp pipeline_id(domain, ip) do
    "pipeline_#{domain}_#{ip}" |> String.replace(".", "_")
  end

  defp pipeline_name(domain, ip) do
    pipeline_id(domain, ip) |> String.to_atom()
  end

  defp parse_pipeline_id("pipeline_" <> rest) do
    # This is a simple parser - in production you'd want something more robust
    parts = String.split(rest, "_")
    ip_parts = Enum.take(parts, -4)  # Last 4 parts are IP
    domain_parts = Enum.drop(parts, -4) |> Enum.take(length(parts) - 4)
    
    domain = Enum.join(domain_parts, ".") |> String.replace("_", ".")
    ip = Enum.join(ip_parts, ".")
    
    {domain, ip}
  end

  defp calculate_processor_concurrency(policy) do
    # Conservative concurrency based on provider limits
    max_rate = Map.get(policy, :max_messages_per_minute, 1000)
    
    case max_rate do
      rate when rate >= 5000 -> 4  # High volume providers
      rate when rate >= 1000 -> 2  # Standard providers like Gmail
      _ -> 1  # Conservative for others
    end
  end

  defp provider_batch_config(policy) do
    max_rate = Map.get(policy, :max_messages_per_minute, 1000)
    max_connections = Map.get(policy, :max_connections, 10)
    
    # Calculate batch size and timeout based on provider limits
    batch_size = min(50, div(max_rate, 20))  # Conservative batching
    batch_timeout = 5_000  # 5 second timeout
    concurrency = min(max_connections, 5)  # Respect connection limits
    
    [
      batch_size: batch_size,
      batch_timeout: batch_timeout,
      concurrency: concurrency
    ]
  end
end
