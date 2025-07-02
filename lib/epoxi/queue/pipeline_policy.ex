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

  def new(opts \\ []) do
    struct(PipelinePolicy, opts)
  end

  def retry_batch_size(%PipelinePolicy{batch_size: batch_size}) do
    max(5, div(batch_size, 4))
  end

  def retry_batch_timeout(%PipelinePolicy{batch_timeout: batch_timeout}) do
    max(30_000, batch_timeout * 2)
  end

  def retry_max_connections(%PipelinePolicy{max_connections: connections}) do
    max(2, div(connections, 5))
  end
end
