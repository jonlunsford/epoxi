defmodule Epoxi.Queue.PipelinePolicy do
  @moduledoc """
  Defines the policy for the email processing pipeline.
  """
  defstruct name: :default,
            max_connections: 10,
            max_retries: 5,
            batch_size: 100,
            batch_timeout: 1_000,
            allowed_messages: 1000,
            message_interval: 60_000

  @type t :: %__MODULE__{
          name: atom() | String.t(),
          max_connections: non_neg_integer(),
          max_retries: non_neg_integer(),
          batch_size: non_neg_integer(),
          batch_timeout: non_neg_integer(),
          allowed_messages: non_neg_integer(),
          message_interval: non_neg_integer()
        }

  alias Epoxi.Queue.PipelinePolicy

  @spec new(keyword()) :: PipelinePolicy.t()
  def new(opts \\ []) do
    struct(PipelinePolicy, opts)
  end

  @spec broadway_opts(PipelinePolicy.t()) :: keyword()
  def broadway_opts(%PipelinePolicy{name: name} = policy) do
    [
      name: name,
      producer: producer_config(policy),
      processors: processor_config(policy),
      batchers: batcher_config(policy)
    ]
  end

  defp producer_config(%PipelinePolicy{batch_timeout: timeout, max_retries: retries}) do
    [
      module: {Epoxi.Queue.Producer, [poll_interval: timeout, max_retries: retries]},
      concurrency: 1
    ]
  end

  defp processor_config(%PipelinePolicy{}) do
    [default: [concurrency: 2]]
  end

  defp batcher_config(%PipelinePolicy{} = policy) do
    [
      pending: pending_batcher_config(policy),
      retrying: retrying_batcher_config(policy)
    ]
  end

  defp pending_batcher_config(%PipelinePolicy{
         batch_size: size,
         batch_timeout: timeout,
         max_connections: connections
       }) do
    [
      batch_size: size,
      batch_timeout: timeout,
      concurrency: connections
    ]
  end

  defp retrying_batcher_config(%PipelinePolicy{} = policy) do
    [
      batch_size: retry_batch_size(policy),
      batch_timeout: retry_batch_timeout(policy),
      concurrency: retry_max_connections(policy)
    ]
  end

  defp retry_batch_size(%PipelinePolicy{batch_size: batch_size}) do
    max(5, div(batch_size, 4))
  end

  defp retry_batch_timeout(%PipelinePolicy{batch_timeout: batch_timeout}) do
    max(30_000, batch_timeout * 2)
  end

  defp retry_max_connections(%PipelinePolicy{max_connections: connections}) do
    max(2, div(connections, 5))
  end
end
