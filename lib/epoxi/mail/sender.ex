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
    status: "enqueued",
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
      try do
        case Mailer.deliver(state.email) do
          {:ok, _message} ->
            %{state | status: "delivered"}
          {:error, error, message} ->
            %{state | status: "failed", error: %{type: error, message: message}}
          {error, message} ->
            %{state | status: "failed", error: %{type: error, message: message}}
        end
      catch
        {:temporary_failure, message} ->
          %{state | status: "failed", error: %{type: :temporary_failure, message: message}}
        {:permanent_failure, message} ->
          %{state | status: "failed", error: %{type: :permanent_failure, message: message}}
      end

    report(state)

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
    retries_queue = Queues.Supervisor.available_retries()
    Queues.Retries.enqueue(retries_queue, state)
    state
  end

  defp retry_if_failed(state) do
    state
  end

  defp report(%{error: %{message: {type, destination, {:error, error}}}}) do
    log("ERROR: #{inspect(error)}", :magenta)
    :telemetry.execute([:epoxi, :mail, :sender], %{error: 1}, %{error: error, type: type, destination: destination})
  end

  defp report(%{error: %{message: message, type: type}}) do
    log("ERROR: #{inspect(message)}", :magenta)

    error =
      case Regex.run(~r"\d+\d.+\d.+\d", message) do
        [<< error_code :: binary >>] -> error_code
        nil -> "error code not provided"
      end

    :telemetry.execute([:epoxi, :mail, :sender], %{error: 1}, %{error: error, type: type})
  end

  defp report(%{status: "delivered"} = state) do
    log("SENT: #{inspect(state)}")
    :telemetry.execute([:epoxi, :mail, :sender], %{sent: 1}, %{status: state.status})
  end

  defp log(message, color \\ :cyan) do
    Logger.debug(message, ansi_color: color)
  end
end
