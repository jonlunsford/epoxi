import Config

config :epoxi,
  context_module: Epoxi.Context.ExternalSmtp,
  delivery_producer_module: {Epoxi.Queues.Inbox, []}

# config :epoxi, context_module: Epoxi.SMTP.MailtrapContext
