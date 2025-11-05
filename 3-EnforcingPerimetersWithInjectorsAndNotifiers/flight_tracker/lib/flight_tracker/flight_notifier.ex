defmodule FlightTracker.FlightNotifier do
  alias FlightTracker.MessageBroadcaster
  alias FlightTracker.CraftProjector

  require Logger
  use GenStage

  def start_link(flight_callsign) do
    GenStage.start_link(__MODULE__, flight_callsign)
  end

  def init(callsign) do
    {:consumer, callsign, subscribe_to: [MessageBroadcaster]}
  end

  # GenStage callback for consumers
  def handle_events(events, _from, state) do
    for event <- events do
      handle_event(Cloudevents.from_json!(event), state)
    end

    {:noreply, [], state}
  end

  defp handle_event(
      %Cloudevents.Format.V_1_0.Event{
        type: "org.book.flighttracker.position_reported",
        data: dt
      },
      callsign
    ) do
    aircraft = CraftProjector.get_state_by_icao(dt["icao_address"])
    # it's possible that we don't have the callsign yet
    if String.trim(Map.get(aircraft, :callsign, "")) == callsign do
      Logger.info(
        "#{aircraft.callsign}'s position: #{dt["latitude"]}, #{dt["longitude"]}"
      )
    end
  end

  defp handle_event(_evt, _state) do
    # Do nothing
  end
end
