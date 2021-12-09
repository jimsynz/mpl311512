defmodule MPL3115A2.MixProject do
  use Mix.Project

  @version "0.3.0"

  def project do
    [
      app: :mpl3115a2,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      description: "Driver for the MPL3115A2 altimeter connected via I2C.",
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package do
    [
      maintainers: ["James Harton <james@automat.nz>"],
      licenses: ["Hippocratic"],
      links: %{
        "Source" => "https://gitlab.com/jimsy/mpl3115a2"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_i2c, "~> 1.0", optional: true},
      {:credo, "~> 1.6", only: ~w[dev test]a, runtime: false},
      {:earmark, ">= 1.4.19", only: ~w[dev test]a},
      {:elixir_ale, "~> 1.2", optional: true},
      {:ex_doc, ">= 0.26.0", only: ~w[dev test]a},
      {:git_ops, "~> 2.3", only: ~w[dev test]a, runtime: false},
      {:mimic, "~> 1.1", only: :test},
      {:wafer, "~> 0.3"}
    ]
  end
end
