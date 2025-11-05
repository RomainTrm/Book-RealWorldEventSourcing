#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.EventHandlers.SystemsTrigger do
  alias LunarFrontiers.App.Commands.AdvanceConstruction
  alias LunarFrontiers.App.Events.GameloopAdvanced
  alias LunarFrontiers.App.Application

  alias LunarFrontiers.App.Projectors.Building,
    as: BuildingProjector

  use Commanded.Event.Handler,
    application: Application,
    name: __MODULE__

  def handle(%GameloopAdvanced{tick: tick}, _metadata) do
    advance_construction(tick)
    :ok
  end

  defp advance_construction(tick) do
    for site_id <- BuildingProjector.active_sites() do
      %AdvanceConstruction{site_id: site_id,
        tick: tick, advance_ticks: 1
      }
      |> Application.dispatch()
    end
  end
end
