defmodule KinoZoetrope.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_zoetrope,
      version: "0.1.0",
      elixir: "~> 1.18",
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
      {:nx, "~> 0.10.0"},
      {:kino, "~> 0.18.0"},
      {:image, "~> 0.62.1"}
    ]
  end
end
