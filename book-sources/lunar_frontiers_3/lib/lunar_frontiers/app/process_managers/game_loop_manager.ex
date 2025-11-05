#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.ProcessManagers.GameLoopManager do
  require Logger
  alias LunarFrontiers.App.Commands.AdvanceConstruction

  alias LunarFrontiers.App.Events.{
    GameloopAdvanced,
    GameStarted,
    ConstructionCompleted,
    SiteSpawned,
    GameStopped
  }

  alias __MODULE__

  use Commanded.ProcessManagers.ProcessManager,
    application: LunarFrontiers.App.Application,
    name: __MODULE__

  @derive Jason.Encoder
  defstruct [
    :current_tick,
    :active_construction_sites,
    :game_id
  ]

  def interested?(%GameStarted{game_id: gid}), do: {:start, gid}
  def interested?(%SiteSpawned{game_id: gid}), do: {:continue, gid}
  def interested?(%ConstructionCompleted{game_id: gid}), do: {:continue, gid}
  def interested?(%GameloopAdvanced{game_id: gid}), do: {:continue, gid}
  def interested?(%GameStopped{game_id: gid}), do: {:stop, gid}
  def interested?(_event), do: false

  def handle(%__MODULE__{} = state, %GameloopAdvanced{tick: tick}) do
    sites = state.active_construction_sites || []

    construction_cmds = sites
      |> Enum.map(fn site_id ->
        %AdvanceConstruction{
          site_id: site_id,
          tick: tick,
          game_id: state.game_id,
          advance_ticks: 1
        }
      end)

    construction_cmds
  end

  def apply(%GameLoopManager{} = state, %GameloopAdvanced{tick: tick}) do
    %GameLoopManager{
      state
      | current_tick: tick
    }
  end

  def apply(%GameLoopManager{} = _state,
    %GameStarted{game_id: gid} = _evt) do
    %GameLoopManager{
      current_tick: 0,
      game_id: gid,
      active_construction_sites: []
    }
  end

  def apply(%GameLoopManager{} = state,
    %SiteSpawned{site_id: sid, tick: t} = _evt) do
    %GameLoopManager{
      current_tick: t,
      game_id: state.game_id,
      active_construction_sites: state.active_construction_sites ++ [sid]
    }
  end

  def apply(%GameLoopManager{} = state,
    %ConstructionCompleted{site_id: sid, tick: t} = _evt) do
    %GameLoopManager{
      current_tick: t,
      game_id: state.game_id,
      active_construction_sites: state.active_construction_sites -- [sid]
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
