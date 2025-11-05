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

  # GenStage callback for consumer
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
    new_state = Map.put(old_state, :callsign, dt["callsign"])
    :ets.insert(:aircraft_table, {dt["icao_address"], new_state})
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
    # CPR coordinates, not GPS
    new_state =
      old_state
      |> Map.put(:longitude, dt["longitude"])
      |> Map.put(:latitude, dt["latitude"])
      |> Map.put(:altitude, dt["altitude"])

    :ets.insert(:aircraft_table, {dt["icao_address"], new_state})
  end

  defp handle_event(_evt) do
    # ignore
  end

  def get_state_by_icao(icao) do
    case :ets.lookup(:aircraft_table, icao) do
      [{_icao, state}] -> state
      [] -> %{icao_address: icao}
    end
  end

  def aircraft_by_callsign(callsign) do
    # Query equivalent to a SQL queyr "SELECT craftdata FROM aircraft WHERE craftdata.callsign = callsign"
    :ets.select(:aircraft_table, [
      {
        {:"$1", :"$2"}, # Set of variables
        [
          {:==, {:map_get, :callsign, :"$2"}, callsign} # Predicate data must pass to be included in result
        ],
        [:"$2"] # Set of column to be return
      }
    ])
    |> List.first()
  end
end
