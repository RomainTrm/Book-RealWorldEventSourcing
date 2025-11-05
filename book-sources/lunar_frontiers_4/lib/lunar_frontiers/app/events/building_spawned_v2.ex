#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.Events.BuildingSpawned.V2 do
  # In this version of the event, a building is spawned with a
  # tick count indicating how many ticks until construction is completed
  @derive Jason.Encoder
  defstruct [:site_id, :game_id, :site_type, :location, :player_id,
             :tick, :completion_ticks]
end
