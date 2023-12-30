defmodule Untangle.MixProject do
  use Mix.Project

  def project do
    [
      app: :untangle,
      version: "0.3.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: "Logging and inspecting with code location information",
      homepage_url: "https://github.com/bonfire-networks/untangle",
      source_url: "https://github.com/bonfire-networks/untangle",
      package: [
        licenses: ["Apache-2.0"],
        # organization: "bonfire",
        links: %{
          "Repository" => "https://github.com/bonfire-networks/untangle",
          "Hexdocs" => "https://hexdocs.pm/untangle"
        }
      ],
      docs: [
        # The first page to display from the docs
        main: "readme",
        # extra pages to include
        extras: ["README.md"]
      ],
      deps: [
        {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
        {:decorator, "~> 1.4"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
