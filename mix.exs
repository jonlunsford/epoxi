defmodule Epoxi.MixProject do
  use Mix.Project

  def project do
    [
      app: :epoxi,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Epoxi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:gen_stage, "~> 1.1"},
      {:gen_smtp, "~> 1.2"},
      {:broadway, "~> 1.2"},
      {:bandit, "~> 1.0"},
      {:req, "~> 0.5.0"},
      {:telemetry, "~> 1.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"}
      # {:telemetry_metrics_statsd, "~> 0.6.1"}
    ]
  end
end
