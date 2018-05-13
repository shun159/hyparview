defmodule Hyparview.MixProject do
  use Mix.Project

  def project do
    [
      app: :hyparview,
      version: "0.1.0",
      elixir: "~> 1.6",
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Hyparview, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.9.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [compile: ["compile", "credo --strict"]]
  end

  defp dialyzer do
    [
      check_plt: true,
      plt_add_deps: :app_tree,
      flags: [:unmatched_returns, :error_handling, :race_conditions],
      ignore_warnings: "dialyzer.ignore-warnings"
    ]
  end
end
