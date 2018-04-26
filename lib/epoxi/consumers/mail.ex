defmodule Epoxi.Consumers.Mail do
  @moduledoc "Acts as a consumer for Producers.Mail"

  use GenServer

  alias Epoxi.SMTP.Mailer

  @default_state %{
    status: "idle",
    email: nil
  }

  def start_link(email) do
    GenServer.start_link(__MODULE__, email)
  end

  def begin_send(pid) do
    GenServer.cast(pid, :begin_send)
  end

  ## Callbacks

  def init(email) do
    schedule_send()
    state = %{@default_state | email: email}
    {:ok, state}
  end

  def handle_info(:begin_send, state) do
    case Mailer.deliver(state.email) do
      {:ok, message} ->
        state = %{state | status: "sent"}
      {:error, type, message} ->
        state = %{state | status: "FAILED: #{type} : #{message}"}
      {:error, reason} ->
        state = %{state | status: "FAILED: #{reason}"}
    end

    IO.inspect state.status

    {:stop, :normal, state}
  end

  def handle_info(message, state) do
    super(message, state)
  end

  defp schedule_send() do
    Process.send(self(), :begin_send, [])
  end
end
