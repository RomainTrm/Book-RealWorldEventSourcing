#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.Application do
  use Application

  alias LunarFrontiers.App

  @impl true
  def start(_type, _args) do
    children = [
      {App.Supervisor, nil}
      # Starts a worker by calling: LunarFrontiers.Worker.start_link(arg)
      # {LunarFrontiers.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LunarFrontiers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
