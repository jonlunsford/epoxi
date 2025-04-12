defmodule Epoxi.Queue.Message do
  @moduledoc """
  Represents a message in the email queue
  """

  defstruct [
    :id,
    :email,
    :context,
    :inserted_at,
    :updated_at,
    :errors,
    :delivery_response,
    :next_retry_at,
    status: :pending,
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
          errors: List.t(),
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
      | errors: [error | message.errors],
        status: :failed,
        updated_at: DateTime.utc_now()
    }
  end

  def mark_retrying(message, next_retry_at) do
    %{
      message
      | status: :retrying,
        next_retry_at: next_retry_at,
        updated_at: DateTime.utc_now(),
        retry_count: message.retry_count + 1
    }
  end

  def time_to_retry?(message) do
    case message.next_retry_at do
      nil ->
        true

      next_retry_at ->
        DateTime.compare(DateTime.utc_now(), next_retry_at) == :gt
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
