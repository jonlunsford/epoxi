defmodule Epoxi.Queue do
  @moduledoc """
  API for interacting with the email queue
  """

  alias Epoxi.{Email, Context, Queue.Message}

  @doc """
  Enqueues an email for delivery
  """
  @spec enqueue(Email.t(), Context.t()) :: {:ok, String.t()} | {:error, term()}
  def enqueue(%Email{} = email, %Context{} = context) do
    id = generate_id()

    message = %Message{
      id: id,
      email: email,
      context: context,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      status: :pending,
      retry_count: 0
    }

    OffBroadwayMemory.Buffer.push(:inbox, message)

    {:ok, id}
  end

  @doc """
  Batch enqueue multiple emails
  """
  @spec batch_enqueue([{Email.t(), Context.t()}]) :: {:ok, [String.t()]} | {:error, term()}
  def batch_enqueue(emails_with_contexts) when is_list(emails_with_contexts) do
    ids =
      Enum.map(emails_with_contexts, fn {email, context} ->
        {:ok, id} = enqueue(email, context)
        id
      end)

    {:ok, ids}
  end

  # Additional utility functions like status, cancel, requeue

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
