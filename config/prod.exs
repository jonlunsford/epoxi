use Mix.Config

config :epoxi,
  endpoint_options: [
    plug: Epoxi.Endpoint,
    scheme: :https,
    port: 443,
    certfile: "",
    keyfile: ""
  ],
  producer_module: OffBroadwayMemory.Producer,
  producer_options: [
    buffer: :inbox,
    on_failure: :discard
  ]
