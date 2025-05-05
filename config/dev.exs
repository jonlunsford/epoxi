import Config

config :epoxi,
  endpoint_options: [
    plug: Epoxi.Endpoint,
    scheme: :http,
    port: 4000
  ],
  producer_module: Epoxi.Queue.Producer,
  producer_options: [
    queue: :inbox
  ]
