#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule LunarFrontiers.App.Projectors.Building do
  alias LunarFrontiers.App.Events.BuildingSpawned
  alias LunarFrontiers.App.Events.SiteSpawned
  alias LunarFrontiers.App.Events.ConstructionProgressed

  use Commanded.Event.Handler,
    application: LunarFrontiers.App.Application,
    name: __MODULE__


  def init(config) do
    {:ok, config}
  end

  def handle(
        %SiteSpawned{
          site_id: site_id,
          site_type: site_type,
          location: location,
          player_id: player_id
        },
        _metadata
      ) do

    building = %{
      complete: 0.0,
      site_id: site_id,
      site_type: site_type,
      player_id: player_id,
      location: location,
      ready: false
    } |> Jason.encode!()

    Redix.command(:projections,
      ["SET", projection_key(site_id), building])
    Redix.command(:projections,
      ["SADD", player_sites_key(player_id), site_id])

    :ok
  end

  def handle(
        %BuildingSpawned{
          site_id: site_id,
          site_type: site_type,
          location: location,
          player_id: player_id,
          tick: t
        },
        _metadata
      ) do

    building = %{
      complete: 100.0,
      site_id: site_id,
      spawned_tick: t,
      site_type: site_type,
      location: location,
      player_id: player_id,
      ready: true
    } |> Jason.encode!()

    Redix.command(:projections, ["SET", projection_key(site_id), building])

    :ok
  end

  def handle(
        %ConstructionProgressed{
          site_id: site_id,
          site_type: site_type,
          location: loc,
          player_id: player_id,
          progressed_ticks: p,
          required_ticks: r
        },
        _metadata
      ) do
    building = %{
      player_id: player_id,
      complete: Float.round(r / p * 100, 1),
      site_id: site_id,
      site_type: site_type,
      location: loc,
      ready: false
    } |> Jason.encode!()

    Redix.command(:projections, ["SET", projection_key(site_id), building])

    :ok
  end

  defp projection_key(id) do
    "building:#{id}"
  end

  defp player_sites_key(player_id) do
    "sites:#{player_id}"
  end

end
