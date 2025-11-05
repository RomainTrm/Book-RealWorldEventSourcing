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
    :ets.new(:buildings, [:named_table, :set, :public])
    :ets.new(:sites, [:named_table, :set, :public])

    {:ok, config}
  end

  def active_sites() do
    :ets.tab2list(:sites) |> Enum.map(fn {site_id, _bldg} -> site_id end)
  end

  def handle(
        %SiteSpawned{
          site_id: site_id,
          site_type: site_type,
          location: location
        },
        _metadata
      ) do
    building = %{
      complete: 0.0,
      site_id: site_id,
      site_type: site_type,
      location: location,
      ready: false
    }

    :ets.insert(:buildings, {site_id, building})
    :ets.insert(:sites, {site_id, building})

    :ok
  end

  def handle(
        %BuildingSpawned{
          site_id: site_id,
          site_type: site_type,
          location: location,
          player_id: player_id
        },
        _metadata
      ) do
    building = %{
      complete: 100.0,
      site_id: site_id,
      site_type: site_type,
      location: location,
      player_id: player_id,
      ready: true
    }

    :ets.insert(:buildings, {site_id, building})
    :ets.delete(:sites, site_id)

    :ok
  end

  def handle(
        %ConstructionProgressed{
          site_id: site_id,
          site_type: site_type,
          location: location,
          progressed_ticks: p,
          required_ticks: r
        },
        _metadata
      ) do
    building = %{
      complete: Float.round(r / p * 100, 1),
      site_id: site_id,
      site_type: site_type,
      location: location
    }

    :ets.insert(:buildings, {site_id, building})

    :ok
  end
end
