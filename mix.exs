defmodule Francis.MixProject do
  use Mix.Project

  @version "0.1.0-pre"

  def project do
    [
      name: "Francis",
      app: :francis,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/filipecabaco/francis",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "A simple wrapper around Plug and Bandit to reduce boilerplate for simple APIs"
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      files: ["lib", "test", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Filipe Cabaço"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/filipecabaco/francis"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      formatters: ["html", "epub"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, ">= 0.7.7"},
      {:jason, "~> 1.4"},
      {:websock, "~> 0.5"},
      {:websock_adapter, "~> 0.5.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:req, "~> 0.4.0", only: [:test]},
      {:websockex, "~> 0.4.3", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
