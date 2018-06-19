defmodule Hyparview.MixProject do
  use Mix.Project

  def project do
    [
      app: :hyparview,
      name: "hyparview",
      version: "0.1.0",
      elixir: "~> 1.6",
      description: description(),
      package: package(),
      source_url: "https://github.com/shun159/hyparview",
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
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev},
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

  defp description do
    "HyParView Implementation In Elixir"
  end

  defp package do
    [
      name: "hyperview",
      files: ["lib", "mix.exs", "README.md", "images"],
      licenses: ["BSD 3-Clause"],
      maintainers: ["Eishun Kondoh (shun159)"],
      links: %{"GitHub" => "https://github.com/shun159/hyparview"}
    ]
  end
end
