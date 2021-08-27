defmodule Vexil.MixProject do
  use Mix.Project

  def project do
    [
      app: :vexil,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.2", only: [:dev, :test], runtime: false},
      {:typed_struct, "~> 0.2.1"}
    ]
  end
end
