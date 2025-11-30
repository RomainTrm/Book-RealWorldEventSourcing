defmodule LunarFrontiers.App.ProcessManagers.GameLoopManager do
  alias LunarFrontiers.App.Commands.AdvanceConstruction
  alias LunarFrontiers.App.Events.{
    GameloopAdvanced,
    GameStarted,
    BuildingSpawned,
    ConstructionCompleted,
    GameStopped
  }

  require Logger

  alias __MODULE__

  use Commanded.ProcessManagers.ProcessManager,
    application: LunarFrontiers.App.Application,
    name: __MODULE__

  @derive Jason.Encoder
  defstruct [:current_tick, :buildings_under_construction, :game_id]

  def interested?(%GameStarted{game_id: gid}), do: {:start, gid}
  def interested?(%BuildingSpawned.V2{game_id: gid}), do: {:continue, gid}
  def interested?(%ConstructionCompleted{game_id: gid}), do: {:continue, gid}
  def interested?(%GameloopAdvanced{game_id: gid}), do: {:continue, gid}
  def interested?(%GameStopped{game_id: gid}), do: {:stop, gid}
  def interested?(_event), do: false

  def handle(%__MODULE__{} = state, %GameloopAdvanced{} = evt) do
    sites = state.buildings_under_construction || []
    construction_cmds = sites
      |> Enum.map(fn site_id ->
        %AdvanceConstruction{
          site_id: site_id,
          tick: evt.tick,
          game_id: state.game_id,
          advance_ticks: 1
        }
      end)
    construction_cmds
  end

  def apply(%GameLoopManager{} = state, %GameloopAdvanced{} = evt) do
    %GameLoopManager{state | current_tick: evt.tick}
  end

  def apply(%GameLoopManager{}, %GameStarted{} = evt) do
    %GameLoopManager{
      game_id: evt.game_id,
      current_tick: 0,
      buildings_under_construction: []
    }
  end

  def apply(%GameLoopManager{} = state, %BuildingSpawned.V2{} = evt) do
    %GameLoopManager{state |
      current_tick: evt.tick,
      buildings_under_construction: state.buildings_under_construction ++ [evt.site_id]
    }
  end

  def apply(%GameLoopManager{} = state, %ConstructionCompleted{} = evt) do
    %GameLoopManager{state |
      current_tick: evt.tick,
      buildings_under_construction: state.buildings_under_construction -- [evt.site_id]
    }
  end

  # By default skip any problematic events
  def error(error, _command_or_event, _failure_context) do
    Logger.error(fn ->
      "#{__MODULE__} encountered an error: #{inspect(error)}"
    end)
  end
end
