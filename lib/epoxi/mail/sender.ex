defmodule Epoxi.Mail.Sender do
  require Logger
  @moduledoc """
  Acts as a consumer for MailDispatcher

  TODO:
  - Handle Mailer.deliver responses (200s, 400s, and 500s)
  - Log delivery results
  """

  use GenServer

  alias Epoxi.SMTP.Mailer
  alias Epoxi.Queues

  @default_state %{
    status: "idle",
    email: nil,
    error: nil
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

  def handle_info(:begin_send, %{email: %Mailman.Email{}} = state) do
    state =
      case Mailer.deliver(state.email) do
        {:ok, _message} ->
          %{state | status: "sent"}
        {:error, type, message} ->
          %{state | status: "failed", error: %{type: type, message: message}}
        {:error, reason} ->
          %{state | status: "failed", error: %{reason: reason}}
      end

    log("Attempted Send: #{inspect(state)}")

    state = retry_if_failed(state)

    {:stop, :normal, state}
  end

  def handle_info(:begin_send, state) do
    {:stop, :normal, state}
  end

  def handle_info(message, state) do
    super(message, state)
  end

  defp schedule_send() do
    Process.send(self(), :begin_send, [])
  end

  defp retry_if_failed(%{error: error} = state) when is_map(error) do
    log("Adding to retries queue: #{inspect(state)}", :magenta)
    failed_queue = Queues.Supervisor.failed_queue()
    Queues.Retries.enqueue(failed_queue, state)
    state
  end

  defp retry_if_failed(state) do
    state
  end

  defp log(message, color \\ :green) do
    Logger.debug(message, ansi_color: color)
  end
end
