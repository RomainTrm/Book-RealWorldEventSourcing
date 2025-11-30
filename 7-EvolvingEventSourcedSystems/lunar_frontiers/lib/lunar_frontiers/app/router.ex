#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.Router do
  alias LunarFrontiers.App.Commands.{
    AdvanceGameloop,
    AdvanceConstruction,
    SpawnBuilding,
    StartGame
  }

  alias LunarFrontiers.App.Aggregates.{
    Gameloop,
    Building
  }

  use Commanded.Commands.Router

  identify(Gameloop,
    by: :game_id,
    prefix: "game-"
  )

  identify(Building,
    by: :site_id,
    prefix: "bldg-"
  )

  dispatch([AdvanceGameloop, StartGame], to: Gameloop)
  dispatch([SpawnBuilding.V2, AdvanceConstruction], to: Building)
end
