defmodule FirstBricks.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :first_bricks,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]

  def application,
    do: [extra_applications: [:logger, :crypto, :xmerl], mod: {FirstBricks.Application, []}]

  defp deps,
    do: [
      {:phoenix, "~> 1.7.21"},
      {:bandit, "~> 1.10"},
      {:jason, "~> 1.4"},
      {:phoenix_html, "~> 4.2"}
    ]
end
