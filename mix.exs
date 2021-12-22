defmodule Epoxi.MixProject do
  use Mix.Project

  def project do
    [
      app: :epoxi,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:telemetry_poller, :logger, :plug_cowboy],
      mod: {Epoxi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:gen_stage, "~> 1.1"},
      {:mailman, "~> 0.4.3"},
      {:poison, "~> 5.0"},

      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics_statsd, "~> 0.6.1"}
    ]
  end
end
