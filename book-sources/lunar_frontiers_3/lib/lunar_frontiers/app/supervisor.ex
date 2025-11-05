#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.Supervisor do
  use Supervisor

  alias LunarFrontiers.App

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Application
      App.Application,

      # Process Managers
      App.ProcessManagers.Construction,
      App.ProcessManagers.GameLoopManager,

      # Projectors (read model)
      App.Projectors.Building
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
