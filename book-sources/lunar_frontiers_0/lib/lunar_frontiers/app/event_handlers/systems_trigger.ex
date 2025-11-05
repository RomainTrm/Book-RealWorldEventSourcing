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
    # Almost like an ECS, on each tick determine which systems need to be invoked/advanced
    # Some systems might not advance on each tick. For example, you could have combat advance
    # every other tick (tick mod 2), movement advance every tick, and resource generation every 3rd
    # tick (tick mod 3).

    advance_construction(tick)
    :ok
  end

  defp advance_construction(tick) do
    for site_id <- BuildingProjector.active_sites() do
      cmd = %AdvanceConstruction{
        site_id: site_id,
        tick: tick,
        advance_ticks: 1
      }

      Application.dispatch(cmd)
    end
  end
end
