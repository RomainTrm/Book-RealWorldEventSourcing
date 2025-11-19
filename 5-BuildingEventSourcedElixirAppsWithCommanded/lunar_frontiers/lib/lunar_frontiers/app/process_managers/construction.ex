defmodule LunarFrontiers.App.ProcessManagers.Construction do
  alias LunarFrontiers.App.Commands.SpawnBuilding
  alias LunarFrontiers.App.Events.{
    ConstructionCompleted,
    ConstructionProgressed,
    SiteSpawned,
    BuildingSpawned
  }

  require Logger

  use Commanded.ProcessManagers.ProcessManager,
    application: LunarFrontiers.App.Application,
    name: __MODULE__

  @derive Jason.Encoder
  defstruct [:site_id, :tick_started, :ticks_completed, :ticks_required, :status]

  def interested?(%SiteSpawned{} = evt), do: {:start, evt.site_id}
  def interested?(%ConstructionProgressed{} = evt), do: {:continue, evt.site_id}
  def interested?(%ConstructionCompleted{} = evt), do: {:continue, evt.site_id}
  def interested?(%BuildingSpawned{} = evt), do: {:stop, evt.site_id}
  def interested?(_event), do: false

  # Command Dispatch
  def handle(%__MODULE__{}, %ConstructionCompleted{} = evt) do
    %SpawnBuilding{
      site_id: evt.site_id, site_type: evt.site_type, location: evt.location,
      player_id: evt.player_id, tick: evt.tick
    }
  end

  # By default skip any problematic events
  def error(error, _command_or_event, _failure_context) do
    Logger.error(fn ->
      "#{__MODULE__} encountered an error: #{inspect(error)}"
    end)

    :skip
  end
end
