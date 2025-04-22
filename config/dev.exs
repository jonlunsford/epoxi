import Config

config :epoxi,
  endpoint_options: [
    plug: Epoxi.Endpoint,
    scheme: :http,
    port: 4000
  ],
  producer_module: OffBroadwayMemory.Producer,
  producer_options: [
    buffer: :inbox,
    on_failure: :discard
  ]
