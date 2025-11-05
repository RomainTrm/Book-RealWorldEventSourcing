#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.Aggregates.Building do
  alias LunarFrontiers.App.Events.BuildingSpawned
  alias LunarFrontiers.App.Commands.SpawnBuilding
  alias __MODULE__

  defstruct [:site_id, :site_type, :location, :player_id]

  def execute(%Building{} = _bldg, %SpawnBuilding{
        site_id: id, site_type: typ,
        location: loc, player_id: player_id
      }) do
    {:ok,
     %BuildingSpawned{
       site_id: id, site_type: typ, location: loc,
       player_id: player_id}}
  end

  def apply(%Building{} = _bldg, %BuildingSpawned{
        site_id: id, site_type: typ, location: loc,
        player_id: player_id}) do
    %Building{
      site_type: typ, site_id: id, player_id: player_id,
      location: loc}
  end
end
