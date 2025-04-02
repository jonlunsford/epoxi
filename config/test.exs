import Config

config :logger, level: :info

config :epoxi,
  smtp_config: %{
    port: 2525,
    relay: "localhost",
    hostname: "localhost",
    auth: :never
  },
  producer_module: Broadway.DummyProducer,
  producer_options: []
