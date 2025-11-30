defmodule LunarFrontiers.App.Aggregates.Building do
  alias LunarFrontiers.App.Events.{
    BuildingSpawned,
    ConstructionProgressed,
    ConstructionCompleted
  }
  alias LunarFrontiers.App.Commands.{
    SpawnBuilding,
    AdvanceConstruction
  }
  alias __MODULE__

  defstruct [:site_id, :site_type, :location, :player_id, :created_tick, :construction_remaining]

  def execute(%Building{}, %SpawnBuilding.V2{} = cmd) do
    evt = %BuildingSpawned.V2{
      site_id: cmd.site_id, site_type: cmd.site_type,
      location: cmd.location, player_id: cmd.player_id,
      tick: cmd.tick, completion_ticks: cmd.completion_ticks
    }
    {:ok, evt}
  end

  def execute(%Building{} = building, %AdvanceConstruction{} = cmd) do
    building
    |> Multi.new()
    |> Multi.execute(&progress_construction(&1, cmd.tick, cmd.advance_ticks))
    |> Multi.execute(&check_completed(&1, cmd.tick))
  end

  defp progress_construction(building, tick, ticks) do
    evt = %ConstructionProgressed{
      site_id: building.site_id,
      site_type: building.site_type,
      location: building.location,
      progressed_ticks: ticks,
      required_ticks: building.required_ticks,
      tick: tick
    }
    {:ok, evt}
  end

  defp check_completed(%Building{} = building, tick)
       when building.construction_remaining <= 0 do
    %ConstructionCompleted{
      site_id: building.site_id,
      game_id: building.game_id,
      player_id: building.player_id,
      site_type: building.site_type,
      location: building.location,
      tick: tick
    }
  end

  defp check_completed(%Building{}, _tick), do: []

  # State
  def apply(%Building{}, %BuildingSpawned.V2{} = evt) do
    %Building{
      site_id: evt.site_id, site_type: evt.site_type,
      location: evt.location, player_id: evt.player_id,
      created_tick: evt.tick, construction_remaining: evt.completion_ticks
    }
  end

  # Legacy event, in such case building is constructed
  def apply(%Building{}, %BuildingSpawned{} = evt) do
    %Building{
      site_id: evt.site_id, site_type: evt.site_type,
      location: evt.location, player_id: evt.player_id,
      created_tick: evt.tick, construction_remaining: 0
    }
  end

  def apply(%Building{} = building, %ConstructionProgressed{} = evt) do
    construction_remaining = max(building.construction_remaining - evt.progressed_ticks, 0)
    %Building{building | construction_remaining: construction_remaining}
  end
end
