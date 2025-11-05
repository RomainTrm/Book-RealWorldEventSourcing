#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.MixProject do
  use Mix.Project

  def project do
    [
      app: :lunar_frontiers,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LunarFrontiers.Application, []}
    ]
  end

  defp deps do
    [
      {:commanded, "~> 1.4"},
      {:commanded_eventstore_adapter, "~> 1.4"},
      { :uuid, "~> 1.1" },
      {:redix, "~> 1.1"},
      #{:commanded_ecto_projections, "~> 1.3"},
      {:jason, "~> 1.4"}
    ]
  end
end
