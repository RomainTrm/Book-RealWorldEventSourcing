#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.ProcessManagers.Construction do
  alias LunarFrontiers.App.Events.{
    ConstructionCompleted,
    ConstructionProgressed,
    SiteSpawned,
    BuildingSpawned
  }

  alias LunarFrontiers.App.Commands.SpawnBuilding

  require Logger

  use Commanded.ProcessManagers.ProcessManager,
    application: LunarFrontiers.App.Application,
    name: __MODULE__

  @derive Jason.Encoder
  defstruct [:site_id,:tick_started,:ticks_completed,
    :ticks_required,:status]


  def interested?(%SiteSpawned{site_id: site_id}), do: {:start, site_id}
  def interested?(%ConstructionProgressed{site_id: site_id}),
    do: {:continue, site_id}
  def interested?(%ConstructionCompleted{site_id: site_id}),
    do: {:continue, site_id}
  def interested?(%BuildingSpawned{site_id: site_id}),
    do: {:stop, site_id}
  def interested?(_event), do: false

  # Command Dispatch
  def handle(%__MODULE__{},
        %ConstructionCompleted{site_type: site_type, site_id: site_id,
        location: location, player_id: player_id, tick: tick}) do
    %SpawnBuilding{
      site_id: site_id, site_type: site_type,
      location: location, player_id: player_id,
      tick: tick}
  end

  # By default skip any problematic events
  def error(error, _command_or_event, _failure_context) do
    Logger.error(fn ->
      "#{__MODULE__} encountered an error: #{inspect(error)}"
    end)

    :skip
  end
end
