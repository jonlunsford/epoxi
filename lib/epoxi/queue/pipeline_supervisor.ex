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
    result = DynamicSupervisor.terminate_child(__MODULE__, pid)

    # Log pipeline termination for observability
    case find_pipeline_by_pid(pid) do
      {:ok, pipeline_name} ->
        Logger.info("Pipeline #{pipeline_name} terminated")

      :not_found ->
        Logger.debug("Terminated unknown pipeline with PID #{inspect(pid)}")
    end

    result
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
    pipeline_info = extract_pipeline_info(spec, pid)
    Epoxi.NodeRegistry.register_pipeline(Node.self(), pipeline_info)
    Logger.debug("Registered pipeline #{pipeline_info.name} with node registry")
  end

  defp unregister_pipeline_with_node(pid) do
    case find_pipeline_by_pid(pid) do
      {:ok, pipeline_name} ->
        Epoxi.NodeRegistry.unregister_pipeline(Node.self(), pipeline_name)
        Logger.debug("Unregistered pipeline #{pipeline_name} from node registry")

      :not_found ->
        Logger.debug("Pipeline with PID #{inspect(pid)} not found in registry")
    end
  end

  defp extract_pipeline_info(spec, pid) do
    name = extract_pipeline_name(spec)

    %{
      name: name,
      routing_key: name,
      pid: pid,
      started_at: DateTime.utc_now()
    }
  end

  defp extract_pipeline_name({Epoxi.Queue.Pipeline, %{name: name}}) do
    name
  end

  defp extract_pipeline_name({Epoxi.Queue.Pipeline, opts}) when is_list(opts) do
    Keyword.get(opts, :name, :default)
  end

  defp extract_pipeline_name(spec) when is_map(spec) do
    Map.get(spec, :id, :default)
  end

  defp extract_pipeline_name(_), do: :default

  defp find_pipeline_by_pid(pid) do
    case :ets.whereis(:epoxi_node_pipelines) do
      :undefined ->
        :not_found

      _table ->
        find_pipeline_in_table(pid)
    end
  end

  defp find_pipeline_in_table(pid) do
    pipelines = :ets.tab2list(:epoxi_node_pipelines)

    case Enum.find(pipelines, fn {_name, pipeline_info} ->
           pipeline_info.pid == pid
         end) do
      {name, _pipeline_info} -> {:ok, name}
      nil -> :not_found
    end
  end
end
