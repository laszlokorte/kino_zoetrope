defmodule KinoZoetrope.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_zoetrope,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      source_url: "https://github.com/laszlokorte/kino_zoetrope",
      package: package()
    ]
  end

  defp package() do
    %{
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/laszlokorte/kino_zoetrope"}
    }
  end

  defp description() do
    "Helper for rendering 3d and 4d `Nx.Tensor` as image sequences in livebook."
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
      {:image, "~> 0.62.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
