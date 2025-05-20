import Config

config :logger, level: :info

config :epoxi,
  endpoint_options: [
    plug: Epoxi.Endpoint,
    scheme: :http,
    port: 4000
  ],
  producer_module: Broadway.DummyProducer,
  producer_options: [
    inbox_name: :inbox,
    dead_letter_name: :dead
  ]
