defmodule Epoxi.Mail.DeliveryPipeline do
  use Broadway
  require Logger

  alias Epoxi.Mail.JSONDecoder
  alias Epoxi.SMTP.Mailer

  def start_link(_opts) do
    config =
      case Application.fetch_env(:epoxi, :delivery_pipeline) do
        {:ok, options} ->
          Keyword.merge(options, name: __MODULE__)

        _ ->
          raise "delivery_pipeline config not found."
      end

    Broadway.start_link(__MODULE__, config)
  end

  @impl true
  def prepare_messages(messages, _context) do
    Logger.info("Preparing messages #{Enum.count(messages)}")
    IO.inspect(Enum.map(messages, fn message -> JSONDecoder.decode(message.data) end))
    messages
  end

  @impl true
  def handle_message(_processor, message, _context) do
    Logger.info("Handle message")
    message
  end

  @impl true
  def handle_batch(_batcher, messages, _batch_info, %{delivery_module: delivery_module}) do
    Logger.info("Handle batch #{Enum.count(messages)}")
    messages
  end

  #def transform(event, _options) do
    #Logger.info("Transform event")
    #%Broadway.Message{
      #data: event,
      #acknowledger: {__MODULE__, :emails, []}
    #}
  #end

  def ack(:emails, _successful, _failed) do
    :ok
  end

  #defp deliver(%{data: %Mailman.Email{}} = message) do
    #try do
      #case Mailer.deliver(message.data) do
        #{:ok, _message} ->
          #%{state | status: "delivered"}
        #{:error, error, message} ->
          #%{state | status: "failed", error: %{type: error, message: message}}
        #{error, message} ->
          #%{state | status: "failed", error: %{type: error, message: message}}
      #end
    #catch
      #{:temporary_failure, message} ->
        #%{state | status: "failed", error: %{type: :temporary_failure, message: message}}
      #{:permanent_failure, message} ->
        #%{state | status: "failed", error: %{type: :permanent_failure, message: message}}
    #end
  #end
end
