#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule FlightTracker.CraftProjector do
  alias FlightTracker.MessageBroadcaster
  require Logger
  use GenStage

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    :ets.new(:aircraft_table, [:named_table, :set, :public])

    {:consumer, :ok, subscribe_to: [MessageBroadcaster]}
  end

  # GenStage callback for consumers
  def handle_events(events, _from, state) do
    for event <- events do
      handle_event(Cloudevents.from_json!(event))
    end

    {:noreply, [], state}
  end

  defp handle_event(%Cloudevents.Format.V_1_0.Event{
         type: "org.book.flighttracker.aircraft_identified",
         data: dt
       }) do
    old_state = get_state_by_icao(dt["icao_address"])

    :ets.insert(
      :aircraft_table,
      {dt["icao_address"], Map.put(old_state, :callsign, dt["callsign"])}
    )
  end

  defp handle_event(%Cloudevents.Format.V_1_0.Event{
         type: "org.book.flighttracker.velocity_reported",
         data: dt
       }) do
    old_state = get_state_by_icao(dt["icao_address"])

    new_state =
      old_state
      |> Map.put(:heading, dt["heading"])
      |> Map.put(:ground_speed, dt["ground_speed"])
      |> Map.put(:vertical_rate, dt["vertical_rate"])

    :ets.insert(:aircraft_table, {dt["icao_address"], new_state})
  end

  defp handle_event(%Cloudevents.Format.V_1_0.Event{
         type: "org.book.flighttracker.position_reported",
         data: dt
       }) do
    old_state = get_state_by_icao(dt["icao_address"])

    # These coordinates are in CPR, not the familiar GPS format we're used to
    new_state =
      old_state
      |> Map.put(:longitude, dt["longitude"])
      |> Map.put(:latitude, dt["latitude"])
      |> Map.put(:altitude, dt["altitude"])

    :ets.insert(:aircraft_table, {dt["icao_address"], new_state})
  end

  defp handle_event(_e) do
    # ignore
  end

  def get_state_by_icao(icao) do
    case :ets.lookup(:aircraft_table, icao) do
      [{_icao, state}] ->
        state

      [] ->
        %{icao_address: icao}
    end
  end

  def aircraft_by_callsign(callsign) do
    :ets.select(:aircraft_table, [
      {
        {:"$1", :"$2"},
        [
          {:==, {:map_get, :callsign, :"$2"}, callsign}
        ],
        [:"$2"]
      }
    ])
    |> List.first()
  end
end
