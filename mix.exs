defmodule Where.MixProject do
  use Mix.Project

  def project do
    [
      app: :where,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: "Logging and inspecting with location information.",
      homepage_url: "https://github.com/bonfire-networks/where",
      source_url: "https://github.com/bonfire-networks/where",
      package: [
        licenses: ["Apache-2.0"],
        links: %{
          "Repository" => "https://github.com/bonfire-networks/where",
          "Hexdocs" => "https://hexdocs.pm/where",
        },
      ],
      docs: [
        main: "readme", # The first page to display from the docs 
        extras: ["README.md"], # extra pages to include
      ],
      deps: [{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}],
    ]
  end

  def application, do: [extra_applications: [:logger]]

end
