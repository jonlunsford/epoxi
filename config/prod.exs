use Mix.Config

config :epoxi, context_module: Epoxi.SMTP.Context,
  delivery_producer_module: {Epoxi.Queues.Inbox, []}
