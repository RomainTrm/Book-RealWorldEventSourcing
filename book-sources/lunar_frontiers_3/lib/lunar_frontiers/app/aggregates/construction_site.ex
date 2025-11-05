#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.Aggregates.ConstructionSite do
  alias LunarFrontiers.App.Events.{
    SiteSpawned,
    ConstructionProgressed,
    ConstructionCompleted
  }

  alias LunarFrontiers.App.Commands.{SpawnSite, AdvanceConstruction}
  alias __MODULE__

  alias Commanded.Aggregate.Multi

  defstruct [
    :site_id,
    :game_id,
    :site_type,
    :location,
    :required_ticks,
    :completed_ticks,
    :created_tick,
    :player_id,
    :completed,
    :completed_tick
  ]

  # Command Handlers

  def execute(
        %ConstructionSite{} = _site,
        %SpawnSite{} = cmd
      ) do
    %SpawnSite{
      site_id: id,
      game_id: gid,
      site_type: typ,
      completion_ticks: ticks,
      location: loc,
      tick: now_tick,
      player_id: player_id
    } = cmd

    event = %SiteSpawned{
      site_id: id,
      game_id: gid,
      site_type: typ,
      location: loc,
      tick: now_tick,
      remaining_ticks: ticks,
      player_id: player_id
    }

    {:ok, event}
  end

  def execute(
        %ConstructionSite{} = site,
        %AdvanceConstruction{} = cmd
      ) do
    site
    |> Multi.new()
    |> Multi.execute(&progress_construction(&1, cmd.tick, cmd.advance_ticks))
    |> Multi.execute(&check_completed(&1, cmd.tick))
  end

  defp progress_construction(site, tick, ticks) do
    event = %ConstructionProgressed{
      site_id: site.site_id,
      site_type: site.site_type,
      game_id: site.game_id,
      location: site.location,
      player_id: site.player_id,
      progressed_ticks: ticks,
      required_ticks: site.required_ticks,
      tick: tick
    }

    {:ok, event}
  end

  defp check_completed(
         %ConstructionSite{
           completed_ticks: c,
           required_ticks: r
         } = site,
         tick
       )
       when c >= r do
    %ConstructionCompleted{
      site_id: site.site_id,
      game_id: site.game_id,
      player_id: site.player_id,
      site_type: site.site_type,
      location: site.location,
      tick: tick
    }
  end

  defp check_completed(%ConstructionSite{}, _tick), do: []

  # State Mutators

  def apply(%ConstructionSite{} = _site, %SiteSpawned{} = event) do
    %SiteSpawned{
      site_id: id,
      game_id: gid,
      site_type: typ,
      location: loc,
      tick: now_tick,
      remaining_ticks: ticks,
      player_id: player_id
    } = event

    %ConstructionSite{
      site_type: typ,
      site_id: id,
      game_id: gid,
      player_id: player_id,
      location: loc,
      created_tick: now_tick,
      required_ticks: ticks,
      completed_ticks: 0,
      completed: false
    }
  end

  def apply(
        %ConstructionSite{} = site,
        %ConstructionProgressed{} = event
      ) do
    %ConstructionProgressed{progressed_ticks: progressed} = event

    %ConstructionSite{
      site
      | completed_ticks: site.completed_ticks + progressed
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
end
