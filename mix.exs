defmodule RedixCluster.Mixfile do
  use Mix.Project

  def project do
    [app: :redix_cluster,
     version: "0.0.1",
     elixir: "~> 1.6",
     build_embedded: Mix.env in [:prod],
     start_permanent: Mix.env == :prod,
     preferred_cli_env: [espec: :test],
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [mod: {RedixCluster, []},
    extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [ {:redix, "~> 0.10.0"},
      {:poolboy, "~> 1.5", override: true},
      {:dialyze, "~> 0.2", only: :dev},
      {:dogma, "~> 0.0", only: :dev},
      {:crc, "~> 0.5"},
      {:espec, "~> 1.7.0", only: :test},
      {:benchfella, github: "alco/benchfella", only: :bench},
      {:eredis_cluster, github: "adrienmo/eredis_cluster", only: :bench},
    ]
  end
end
