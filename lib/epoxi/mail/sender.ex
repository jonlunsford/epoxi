defmodule Epoxi.Mail.Sender do
  @moduledoc """
  Acts as a consumer for MailDispatcher

  TODO:
  - Handle Mailer.deliver responses (200s, 400s, and 500s)
  - Log delivery results
  """

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

  def handle_info(:begin_send, %{email: %Mailman.Email{}} = state) do
    state =
      case Mailer.deliver(state.email) do
        {:ok, _message} ->
          %{state | status: "sent"}
        {:error, _type, _message} ->
          %{state | status: "FAILED"}
        {:error, _reason} ->
          %{state | status: "FAILED"}
      end

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
end