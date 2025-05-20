use Mix.Config

config :epoxi,
  endpoint_options: [
    plug: Epoxi.Endpoint,
    scheme: :https,
    port: 443,
    certfile: "",
    keyfile: ""
  ],
  producer_module: Epoxi.Queue.Producer,
  producer_options: [
    queue: :inbox
  ]
