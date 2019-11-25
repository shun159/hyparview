defmodule Hyparview.MixProject do
  use Mix.Project

  def project do
    [
      app: :hyparview,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Hyparview.Application, []}
    ]
  end

  defp deps do
    [
      {:node_monitor, "~> 0.1.0"},
      # Code Quality
      {:credo, "~> 1.1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      # Document
      {:earmark, "~> 1.4.2", only: :doc, runtime: false},
      {:ex_doc, "~> 0.21.1", only: :doc, runtime: false},
      # Test
      {:excoveralls, "~> 0.12", only: :test},
      {:local_cluster, "~> 1.1", only: [:test]}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit],
      flags: [:error_handling, :underspecs, :unmatched_returns],
      ignore_warnings: "dialyzer_ignore.exs"
    ]
  end
end
