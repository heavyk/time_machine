defmodule TimeMachine.MixProject do
  use Mix.Project

  def project do
    [
      app: :time_machine,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {TimeMachine.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:estree, path: "../elixir-estree"},
      {:marker, path: "../marker"},
      {:focus, "~> 0.3", only: :test},
      {:colors, "~> 1.1"},
      {:mix_test_watch, "~> 0.5", only: :dev, runtime: false}
    ]
  end
end
