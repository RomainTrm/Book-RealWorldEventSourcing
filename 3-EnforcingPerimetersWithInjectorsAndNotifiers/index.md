# 3. Enforcing Perimeters with Injectors and Notifiers

So far, we've seen *aggregates* are basically two functions, one that takes events to produce an internal state, and one that takes a command to produce events. We've also met *projectors* that transform a stream of events to query-friendly data views.  

Now we'll introduce *injectors* and *notifiers* to exchange with the outside world. They will allow us to manage side effects without impacting the pure functional nature of the rest of our system.  

## Handling Input and Output in an Event-Sourced World

*Aggregates* and *projectors* are not allowed to access some external values like the system time, overwise this would break the pureness and predictability of the system. Though, values outside of our system keeps changing (like the outside temperature or stock prices), so we need to inject these changes into our system.  

## Reacting to Injected Events

The code to react to an injected event is just an event handler. But we have to ask ourselves if we want to inject an external event and where. Here are some questions to answer in order to drive our decision:  

- Does the external event represent something important to the components in our system?
- Does the event occur without the aid of an internal command?
- Does the occurrence of the event have meaning beyond the ephemeral state?
- Does the occurrence of the event also affect the state of an aggregate in our system?

## Notify External Consumers

To notify external consumers, we do the opposite operation. A notifier listens to internal events and does some messaging when necessary. Building an external message may necessitate some querying from projections.  
Notifiers are intended to be used for external communication, if we want to trigger further internal processing, then this is the job of another building block: the *process manager*.  

## Introducing Cloud Events

For ordering cloud events, if we're using a single Events-Store that can ensure global ordering, then the author claims that timestamps are sufficient. I'm suspicious here: order can be corrupt if the system clock changes or if two events are stored with the same timestamp.  
Overwise, we may have to rely on [CRTSs (Conflict-free Replicated Data Types)](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type) or [Lamport clock](https://en.wikipedia.org/wiki/Lamport_timestamp).

[Cloud Events](https://cloudevents.io/) is an attempt at a canonical event format. These events include:  

- `specversion` The version of Cloud Events to which this event conforms.
- `type` A fully qualified name of the event type.
- `source` A free-form identifier indicator the originator of the event.
- `id` A unique identifier for the event.
- `datacontenttype` A mime type that indicates the type of data that can be found in the `data` field.
- `time` A ISO 8601 string formatted timestamp.
- `data` The payload.

Here's an example of notifier producing a Cloud event (using the [Cloudevents library](https://hex.pm/packages/cloudevents) available on [hex.pm](https://hex.pm/)):  

```elixir
  defp new_cloudevent(type, data) do
    %{
      "specversion" => "1.0",
      "type" => "org.book.filghttracker.#{String.downcase(type)}",
      "source" => "radio_aggregator",
      "id" => UUID.uuid4(),
      "datacontenttype" => "application/json",
      "time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => data
    }
    |> Cloudevents.from_map!()
    |> Cloudevents.to_json()
  end
```

produces

```json
{
    "data": {...},
    "id": "99579825-5252-4100-8f02-c652bead4f00",
    "type": "org.book.filghttracker.aircraft_identified",
    "time": "2025-11-05T09:22:47.307000Z",
    "source": "radio_aggregator",
    "datacontenttype": "application/json",
    "specversion": "1.0"
}
```

## Building a Flight Tracker when Injection and Notification

In the application, we will capture real-time flight data sources and inject them into our internal event stream.  
As this requires some hardware, we will use some test data but this can be achieved with a radio antenna.  
We'll be taking various [ADB-S](https://www.faa.gov/air_traffic/technology/adsb) messages and inject them. They will be used to populate projections. Then we will build a fake notifier that sends notifications to a third party.  

We'll inject the following events:  

- Aircraft identified
- Squawk received
- Position reported
- Velocity reported

First, we create a new project: ``mix new flight_tracker --sup`  
Then we build a [message broadcaster](./flight_tracker/lib/flight_tracker/message_broadcaster.ex) and a [projector](./flight_tracker/lib/flight_tracker/craft_projector.ex). All sources are available in this [directory](./flight_tracker/).  

### Getting ADS-B Messages

Now we can start injecting ADS-S messages that are encoded with the "Mode S" encoding.  
Fake data are available in this [file](./flight_tracker/modes_sample.txt).  
To avoid complexity here, these have been [converted](./flight_tracker/sample_cloudevents.json) by the author to the Cloud Event format.  
Now we want to inject the file into our system with a dedicated [injector](./flight_tracker/lib/flight_tracker/file_injector.ex).  
Then we build the [flight notifier](./flight_tracker/lib/flight_tracker/flight_notifier.ex) to send (fake) external notifications.

### Running the Flight Tracker

Now, we need to configure our [application](./flight_tracker/lib/flight_tracker/application.ex) by declaring our building blocks. Then, we can run our application:  

```elixir
...> iex -S mix
12:07:06.771 [info] AMC421's position: 24031.0, 104828.0
12:07:06.780 [info] AMC421's position: 24018.0, 104834.0
12:07:06.781 [info] AMC421's position: 10492.0, 99821.0
12:07:06.781 [info] AMC421's position: 10453.0, 99836.0
12:07:06.781 [info] AMC421's position: 10418.0, 99851.0
[...]
iex> FlightTracker.CraftProjector.aircraft_by_callsign("AMC421")
%{
  callsign: "AMC421",
  heading: 157.85973327466598,
  ground_speed: 376.78243058826405,
  vertical_rate: -1792,
  longitude: 105731.0,
  latitude: 21761.0,
  altitude: 20750,
  icao_address: "4D2023"
}
```
