defmodule Epoxi.Queue.Message do
  @moduledoc """
  Represents a message in the email queue
  """

  defstruct [
    # Unique ID for the message
    :id,
    # The Email struct
    :email,
    # The Context struct
    :context,
    # When the message was inserted into the queue
    :inserted_at,
    # When the message was last updated
    :updated_at,
    # Error information if any
    :error,
    # Response from the SMTP server
    :delivery_response,
    # When to retry the message next
    :next_retry_at,
    # Status: pending, processing, delivered, retrying, failed
    status: :pending,
    # Number of retry attempts
    retry_count: 0
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          email: Epoxi.Email.t(),
          context: Epoxi.Context.t(),
          delivery_response: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: atom(),
          retry_count: non_neg_integer(),
          error: term(),
          next_retry_at: DateTime.t() | nil
        }

  def new(attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put_new(:id, generate_id())
      |> Map.put_new(:inserted_at, DateTime.utc_now())
      |> Map.put_new(:updated_at, DateTime.utc_now())

    struct(__MODULE__, attrs)
  end

  def mark_delivered(message, delivery_response) do
    %{
      message
      | delivery_response: delivery_response,
        status: :delivered,
        updated_at: DateTime.utc_now()
    }
  end

  def mark_failed(message, error) do
    %{
      message
      | error: error,
        status: :failed,
        updated_at: DateTime.utc_now()
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
