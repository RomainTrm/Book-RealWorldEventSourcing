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

  defstruct [
    :site_id,
    :site_type,
    :location,
    :player_id,
    :created_tick,
    :construction_remaining
  ]

  def execute(%Building{} = _bldg, %SpawnBuilding.V2{
        site_id: id,
        site_type: typ,
        location: loc,
        player_id: player_id,
        tick: t,
        completion_ticks: completion_ticks
      }) do
    {:ok,
     %BuildingSpawned.V2{
       site_id: id,
       site_type: typ,
       location: loc,
       player_id: player_id,
       tick: t,
       completion_ticks: completion_ticks
     }}
  end

  def execute(
        %Building{} = building,
        %AdvanceConstruction{} = cmd
      ) do
    building
    |> Multi.new()
    |> Multi.execute(&progress_construction(&1, cmd.tick, cmd.advance_ticks))
    |> Multi.execute(&check_completed(&1, cmd.tick))
  end

  def apply(%Building{} = _bldg, %BuildingSpawned.V2{
        site_id: id,
        site_type: typ,
        location: loc,
        player_id: player_id,
        tick: t,
        completion_ticks: completion_ticks
      }) do
    %Building{
      site_type: typ,
      created_tick: t,
      site_id: id,
      player_id: player_id,
      location: loc,
      construction_remaining: completion_ticks
    }
  end

  def apply(
        %Building{} = building,
        %ConstructionProgressed{} = event
      ) do
    %ConstructionProgressed{progressed_ticks: progressed} = event

    %Building{
      building
      | construction_remaining:
          max(
            building.construction_remaining - progressed,
            0
          )
    }
  end

  def apply(
        %ConstructionSite{} = site,
        %ConstructionCompleted{} = event
      ) do
    %ConstructionSite{
      site
      | completed: true,
        completed_tick: event.tick
    }
  end

  defp progress_construction(site, tick, ticks) do
    {:ok,
     %ConstructionProgressed{
       site_id: site.site_id,
       site_type: site.site_type,
       game_id: site.game_id,
       location: site.location,
       player_id: site.player_id,
       progressed_ticks: ticks,
       required_ticks: site.required_ticks,
       tick: tick
     }}
  end

  defp check_completed(
         %Building{
           construction_remaining: r
         } = building,
         tick
       )
       when r <= 0 do
    %ConstructionCompleted{
      site_id: building.site_id,
      game_id: building.game_id,
      player_id: building.player_id,
      site_type: building.site_type,
      location: building.location,
      tick: tick
    }
  end

  defp check_completed(%ConstructionSite{}, _tick), do: []
end
