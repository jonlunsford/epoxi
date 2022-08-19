use Mix.Config

config :epoxi, context_module: Epoxi.SMTP.LocalContext,
  delivery_producer_module: {Epoxi.Queues.Inbox, []}
#config :epoxi, context_module: Epoxi.SMTP.MailtrapContext
