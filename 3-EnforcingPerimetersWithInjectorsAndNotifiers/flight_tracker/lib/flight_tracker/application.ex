defmodule FlightTracker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {FlightTracker.FileInjector, ["./sample_cloudevents.json"]},
      {FlightTracker.MessageBroadcaster, []},
      {FlightTracker.CraftProjector, []},
      {FlightTracker.FlightNotifier, "AMC421"}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: FlightTracker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
