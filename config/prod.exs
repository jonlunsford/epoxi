use Mix.Config

config :epoxi,
  smtp_config: %{
    port: 2525,
    relay: "localhost",
    hostname: "localhost",
    auth: :never
  },
  producer_module: OffBroadwayMemory.Producer,
  producer_options: [
    name: :inbox
  ]
