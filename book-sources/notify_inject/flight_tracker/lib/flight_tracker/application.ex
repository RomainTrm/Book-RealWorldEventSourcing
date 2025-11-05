#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule FlightTracker.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {FlightTracker.FileInjector, ["./sample_cloudevents.json"]},
      {FlightTracker.MessageBroadcaster, []},
      {FlightTracker.CraftProjector, []},
      {FlightTracker.FlightNotifier, "AMC421"}
    ]

    opts = [strategy: :rest_for_one, name: FlightTracker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
