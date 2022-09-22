import Config

config :logger, level: :info

config :epoxi,
  delivery_pipeline: [
    producer: [
      module: {Broadway.DummyProducer, []},
      transformer: {Epoxi.Mail.DeliveryPipeline, :transform, []}
    ],
    processors: [
      default: []
    ],
    batchers: [
      default: [batch_size: 1]
    ],
    context: %{
      delivery_module: Epoxi.Test.Context
    }
  ]
