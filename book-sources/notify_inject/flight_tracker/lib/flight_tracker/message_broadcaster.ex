#---
# Excerpted from "Real-World Event Sourcing",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/khpes for more book information.
#---
defmodule FlightTracker.MessageBroadcaster do
  use GenStage
  require Logger

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Injects a raw message that is not in cloud event format
  """
  def broadcast_message(message) do
    GenStage.call(__MODULE__, {:notify, message})
  end

  @doc """
  Injects a cloud event to be published to the stage pipeline
  """
  def broadcast_event(evt) do
    GenStage.call(__MODULE__, {:notify_evt, evt})
  end

  @impl true
  def init(:ok) do
    {:producer, :ok, dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl true
  def handle_call({:notify, message}, _from, state) do
    {:reply, :ok, [to_event(message)], state}
  end

  @impl true
  def handle_call({:notify_evt, evt}, _from, state) do
    {:reply, :ok, [evt], state}
  end

  @impl true
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  defp to_event(%{type: :aircraft_identified,
        message: %{icao_address: _icao, callsign: _callsign,
        emitter_category: _cat} = msg
       }) do
    new_cloudevent("aircraft_identified", msg)
  end

  defp to_event(%{type: :squawk_received,
    message: %{squawk: _squawk, icao_address: _icao} = msg}) do
    new_cloudevent("squawk_received", msg)
  end

  defp to_event(%{type: :position_reported, message: %{
    icao_address: icao, position: %{
      altitude: alt, longitude: long, latitude: lat}}}) do
    new_cloudevent("position_reported", %{
      altitude: alt, longitude: long, latitude: lat,
      icao_address: icao
    })
  end

  defp to_event(%{type: :velocity_reported, message:
    %{heading: _head, ground_speed: _gs, vertical_rate: _vr,
      vertical_rate_source: vrs} = msg}) do
    source =
      case vrs do
        :barometric_pressure -> "barometric"
        :geometric -> "geometric"
        _ -> "unknown"
      end

    new_cloudevent("velocity_reported", %{msg | vertical_rate_source: source})
  end

  defp to_event(msg) do
    Logger.error("Unknown message: #{inspect(msg)}")
    %{}
  end

  defp new_cloudevent(type, data) do
    %{
      "specversion" => "1.0",
      "type" => "org.book.flighttracker.#{String.downcase(type)}",
      "source" => "radio_aggregator",
      "id" => UUID.uuid4(),
      "datacontenttype" => "application/json",
      "time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => data
    }
    |> Cloudevents.from_map!()
    |> Cloudevents.to_json()
  end
end
