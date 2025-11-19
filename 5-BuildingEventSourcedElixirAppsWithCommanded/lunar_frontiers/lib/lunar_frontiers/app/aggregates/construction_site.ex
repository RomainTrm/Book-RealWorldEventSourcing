defmodule LunarFrontiers.App.Aggregates.ConstructionSite do
  alias LunarFrontiers.App.Events.{
    SiteSpawned,
    ConstructionProgressed,
    ConstructionCompleted
  }
  alias LunarFrontiers.App.Commands.{SpawnSite, AdvanceConstruction}
  alias __MODULE__
  alias Commanded.Aggregate.Multi

  defstruct [:site_id, :site_type, :location, :required_ticks,
    :completed_ticks, :created_tick, :player_id, :completed,
    :completed_tick]

  # Command Handlers

  def execute(%ConstructionSite{}, %SpawnSite{} = cmd) do
    evt = %SiteSpawned{
      site_id: cmd.site_id, site_type: cmd.site_type, location: cmd.location,
      tick: cmd.tick, remaining_ticks: cmd.completion_ticks, player_id: cmd.player_id
    }
    {:ok, evt}
  end

  def execute(%ConstructionSite{} = site, %AdvanceConstruction{} = cmd) do
    site
    |> Multi.new()
    |> Multi.execute(&progress_construction(&1, cmd.tick, cmd.advance_ticks))
    |> Multi.execute(&check_completed(&1, cmd.tick))
  end

  defp progress_construction(site, tick, ticks) do
    evt = %ConstructionProgressed{
      site_id: site.site_id, site_type: site.site_type, location: site.location,
      progressed_ticks: ticks, required_ticks: site.required_ticks, tick: tick
    }
    {:ok, evt}
  end

  defp check_completed(%ConstructionSite{} = site, tick)
  when site.completed_ticks >= site.required_ticks do
    %ConstructionCompleted{
      site_id: site.site_id, site_type: site.site_type, location: site.location,
      player_id: site.player_id, tick: tick
    }
  end

  defp check_completed(%ConstructionSite{}, _tick), do: []

  # State Mutators

  def apply(%ConstructionSite{}, %SiteSpawned{} = evt) do
    %ConstructionSite{
      site_id: evt.site_id, site_type: evt.site_type, location: evt.location,
      player_id: evt.player_id, created_tick: evt.tick, required_ticks: evt.remaining_ticks,
      completed_ticks: 0, completed: false
    }
  end

  def apply(%ConstructionSite{} = site, %ConstructionProgressed{} = evt) do
    %ConstructionSite{site | completed_ticks: site.completed_ticks + evt.progressed_ticks}
  end

  def apply(%ConstructionSite{} = site, %ConstructionCompleted{} = evt) do
    %ConstructionSite{site | completed_tick: evt.tick, completed: true}
  end
end
