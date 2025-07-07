defmodule Epoxi.Queue.PipelineSupervisor do
  @moduledoc """
  Supervisor for managing dynamic Epoxi pipelines.

  This supervisor automatically registers and unregisters pipelines
  with the node registry for distributed discovery.
  """

  use DynamicSupervisor
  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_child(spec) do
    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} = success ->
        register_pipeline_with_node(spec, pid)
        success

      {:error, {:already_started, pid}} = already_started ->
        register_pipeline_with_node(spec, pid)
        already_started

      error ->
        error
    end
  end

  def terminate_child(pid) when is_pid(pid) do
    unregister_pipeline_with_node(pid)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @impl true
  def init(_opts) do
    # Initialize the node pipeline registry table if it doesn't exist
    case :ets.whereis(:epoxi_node_pipelines) do
      :undefined ->
        :ets.new(:epoxi_node_pipelines, [:named_table, :public, :set])

      _table ->
        :ok
    end

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp register_pipeline_with_node(spec, pid) do
    try do
      pipeline_info = extract_pipeline_info(spec, pid)
      Epoxi.Node.register_pipeline(pipeline_info)

      Logger.debug("Registered pipeline #{pipeline_info.name} with node registry")
    rescue
      error ->
        Logger.warning("Failed to register pipeline with node: #{inspect(error)}")
    end
  end

  defp unregister_pipeline_with_node(pid) do
    try do
      # Find the pipeline by PID and unregister it
      case find_pipeline_by_pid(pid) do
        {:ok, pipeline_name} ->
          Epoxi.Node.unregister_pipeline(pipeline_name)
          Logger.debug("Unregistered pipeline #{pipeline_name} from node registry")

        :not_found ->
          Logger.debug("Pipeline with PID #{inspect(pid)} not found in registry")
      end
    rescue
      error ->
        Logger.warning("Failed to unregister pipeline from node: #{inspect(error)}")
    end
  end

  defp extract_pipeline_info(spec, pid) do
    name = extract_pipeline_name(spec)
    routing_key = extract_routing_key(spec)
    policy = extract_policy(spec)

    %{
      name: name,
      routing_key: routing_key,
      pid: pid,
      policy: policy,
      started_at: DateTime.utc_now()
    }
  end

  defp extract_pipeline_name({Epoxi.Queue.Pipeline, opts}) do
    Keyword.get(opts, :name, :default)
  end

  defp extract_pipeline_name(spec) when is_map(spec) do
    Map.get(spec, :id, :default)
  end

  defp extract_pipeline_name(_), do: :default

  defp extract_routing_key({Epoxi.Queue.Pipeline, opts}) do
    Keyword.get(opts, :routing_key)
  end

  defp extract_routing_key(_), do: nil

  defp extract_policy({Epoxi.Queue.Pipeline, opts}) do
    Keyword.get(opts, :policy)
  end

  defp extract_policy(_), do: nil

  defp find_pipeline_by_pid(pid) do
    case :ets.whereis(:epoxi_node_pipelines) do
      :undefined ->
        :not_found

      _table ->
        pipelines = :ets.tab2list(:epoxi_node_pipelines)

        case Enum.find(pipelines, fn {_name, pipeline_info} ->
               pipeline_info.pid == pid
             end) do
          {name, _pipeline_info} -> {:ok, name}
          nil -> :not_found
        end
    end
  end
end
