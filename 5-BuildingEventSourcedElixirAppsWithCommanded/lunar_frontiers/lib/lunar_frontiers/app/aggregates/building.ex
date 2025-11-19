defmodule LunarFrontiers.App.Aggregates.Building do
  alias LunarFrontiers.App.Events.BuildingSpawned
  alias LunarFrontiers.App.Commands.SpawnBuilding
  alias __MODULE__

  defstruct [:site_id, :site_type, :location, :player_id]

  def execute(%Building{}, %SpawnBuilding{} = cmd) do
    evt = %BuildingSpawned{
      site_id: cmd.site_id, site_type: cmd.site_type,
      location: cmd.location, player_id: cmd.player_id
    }
    {:ok, evt}
  end

  def apply(%Building{}, %BuildingSpawned{} = evt) do
    %Building{
      site_id: evt.site_id, site_type: evt.site_type,
      location: evt.location, player_id: evt.player_id
    }
  end
end
