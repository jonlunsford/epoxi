defmodule Epoxi.MixProject do
  use Mix.Project

  def project do
    [
      app: :epoxi,
      version: "0.1.0",
      elixir: "~> 1.6",
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
      {:credo, "~> 0.9.0-rc1", only: [:dev, :test], runtime: false},
      {:gen_stage, "~> 0.14"},
      {:mailman, github: "mailman-elixir/mailman"},
      {:poison, "~> 3.1"},
      {:plug_cowboy, "~> 2.0"},

      {:telemetry, "~> 0.4.0"},
      {:telemetry_metrics, "~> 0.2.0"},
      {:telemetry_poller, "~> 0.3.0"},
      {:telemetry_metrics_statsd, "~> 0.1.0"}
    ]
  end
end
