# 6. Building Resilient Applications with Event Stores

So far we've worked with volatile data, once the OTP servers stop, their state is lost. In this chapter we'll look at event stores as a mean to persist events and learn how to replay them.  

## Evaluating Event and Projection Stores

In an event-sourced system, we can identify three key types of persistent data, each with their own unique requirements:  

- Aggregate state (snapshots)

    The main interaction pattern is reading and writing by key in atomic operations. As we're manipulating only one element at the time, key-value stores and NoSQL/document-based databases are good candidates.

    > Personal note: I've already stored snapshots in a database, but it was for business analysis and debug purposes. I know this is supposed to be a solution for performance issues due to very long streams of events, but I've never encountered such case.  
    > I tend to believe this is an anti-pattern: if you aggregate needs snapshots, then your aggregate probably have a problem of responsibility and/or life-cycle.  
    > In my opinion, storing snapshots is totally optional to run an event-sourced system.

- Projections (materialized views, read model)

    Projections shape can vary a lot depending on query needs. It's not uncommon to request several items on a single query. Relational databases, key-value and event graph databases are good candidates to store projections.  
    Applications can have multiple projections for a single entity, each tailored to support a specific type of query.  

- Event Log (write model)

    This is the only source of truth within your event-sourced system. Everything else can be destroyed and regenerated on demand as long as you still have the event log. Events are queried in time sequence with little filtering. [*Time series*](https://en.wikipedia.org/wiki/Time_series_database) database is a popular choice as it allows queries to start at a specific event index, number or a given time.  
    Events can also be duplicated in other places to support more high-level analysis (using [*Complex event processing*](https://en.wikipedia.org/wiki/Complex_event_processing) data warehousing).  

As each model has its own requirements, it is normal to use different storage solutions for them.  

## Replaying Events

Replaying events for disaster recovery or model upgrades is one of the superpowers of event sourcing.  
Though, they are few rules to respect to allow replays: when handling events, never depends on side effects like system's time, neither on data outside of events, use pure/referentially transparent functions.

### Verifying Models for Replay

We need to think about our events as permanent. Corrections come in the form of new events. This means that replays of historical events must never fail. Also, two replays of the same event log against the same state should not produce different results.

## Capacity Planning

To maintain an event-sourced application in production, we need to know our event log, aggregate state and projection *growth rate*. This can help plan and configure our infrastructure. It can also inform us about design issues. For example, a huge growth rate might be a sign of a chatty (or cyclic) event model that needs to be refactored.  

A way to compute our growth rate to obtain the storage space consumed per month:  
`size of biggest event * expected events/hour throughput * 24 (hours) * 30 (days)`  

## Exploring Event Store

[*EventStoreDb*](https://www.kurrent.io/) is an open-sourced database that specializes in storing events and real-time streaming.

Install a docker [Event Store](https://hub.docker.com/r/eventstore/eventstore) instance, then run:  

`docker run --name esdb-node -it -p 2113:2113 eventstore/eventstore:latest --insecure --run-projections=All --enable-atom-pub-over-http`

Then we can open Event Store's dashboard on [http://localhost:2113/](http://localhost:2113/).  

We can add events from the "Stream Browser" page, for example  

```json
Stream ID: account-ledger
Event Type: amountDeposited
{
    "accountNumber": "abc",
    "amount": 100
}
```

```json
Stream ID: account-ledger
Event Type: amountWithdrawn
{
    "accountNumber": "abc",
    "amount": 10
}
```

### Creating an EventStoreDB Projection

A projection is a piece of javascript code that runs against the stream.  
We create a new projection `account-balances` in `Continuous` mode.  

```javascript
function getBalance(balances, accountNumber) {
    if (accountNumber in balances) {
        return balances[accountNumber];
    } else {
        return 0;
    }
}

options({
    $includeLinks: false,
    reorderEvents: false,
    processingLag: 0
})

fromStream("account-ledger")
.when({
    $init: function() {
        return {
            balances: {}
        }
    },
    amountDeposited: function(state, event) {
        const evt = JSON.parse(event.bodyRaw);
        const newBalance = 
            getBalance(state.balances, evt.accountNumber) + evt.amount;
        state.balances[evt.accountNumber] = newBalance;
    },
    amountWithdrawn: function(state, event) {
        const evt = JSON.parse(event.bodyRaw);
        const newBalance = 
            getBalance(state.balances, evt.accountNumber) - evt.amount;
        state.balances[evt.accountNumber] = newBalance;
    }
})
.outputState()
```

This is a fluent syntax proposed by *EventStoreDB*. The from `fromStream` builder defines the projection to update. The `init` function defines how to initialize a new projection. `amountDeposited` and `amountWithdrawn` (case sensitive) defines how to apply events. `outputState` stores the new state.  

## Upgrading Lunar Frontiers

In this section, we'll take the Lunar Frontiers game from the previous chapter and upgrade it with a durable event log using Postgres. Commanded library comes with a pluggable system for storing the event log.  

We'll use [commanded_eventstore_adapter](https://hex.pm/packages/commanded_eventstore_adapter). Add in `mix.exs` the following line when run `mix deps.get`:  

```elixir
{:commanded_eventstore_adapter, "~> 1.4"}
```

> Note: `commanded_eventstore_adapter` is a Postgres adapter, to run our application with *EventStoreDB* we should use [commanded_extreme_adapter](https://hex.pm/packages/commanded_extreme_adapter).

Now we have to update our [`config.exs`](./lunar_frontiers/config/config.exs) then declare a new [`EventStore`](./lunar_frontiers/lib/lunar_frontiers/event_store.ex) module.

Now run a docker instance of Postgres: `docker run --name elixir-eventstore -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:14-alpine`  
Then we can make a new plugin called `event_store`:  

```elixir
...> mix do event_store.create, event_store.init
# [...]
The EventStore database has been created.
The EventStore schema already exists.
The EventStore database has been initialized.
```

We can see created tables:  

```bash
...> docker exec -it elixir-eventstore psql -U postgres -d eventstore
psql (14.6)
Type "help" for help.

eventstore=# \dt public.*
               List of relations
 Schema |       Name        | Type  |  Owner
--------+-------------------+-------+----------
 public | events            | table | postgres
 public | schema_migrations | table | postgres
 public | snapshots         | table | postgres
 public | stream_events     | table | postgres
 public | streams           | table | postgres
 public | subscriptions     | table | postgres
(6 rows)
```

Now lets run the REPL to add some events into our event log:  

```elixir
iex> LunarFrontiers.App.Application.dispatch(
...>   %LunarFrontiers.App.Commands.AdvanceGameloop{game_id: 1, tick: 1})
iex> LunarFrontiers.App.Application.dispatch(
...>   %LunarFrontiers.App.Commands.SpawnSite{completion_ticks: 2, location: 1, player_id: 1, site_id: 1, site_type: 1, tick: 1})
iex> LunarFrontiers.App.Application.dispatch(
...>   %LunarFrontiers.App.Commands.AdvanceGameloop{game_id: 1, tick: 2})
iex> LunarFrontiers.App.Application.dispatch(
...>   %LunarFrontiers.App.Commands.AdvanceGameloop{game_id: 1, tick: 3})
```

And now verify our events have been stored:  

```bash
eventstore=# select event_type, metadata from events;
                       event_type                        | metadata
---------------------------------------------------------+----------
 Elixir.LunarFrontiers.App.Events.GameloopAdvanced       | \x7b7d
 Elixir.LunarFrontiers.App.Events.SiteSpawned            | \x7b7d
 Elixir.LunarFrontiers.App.Events.GameloopAdvanced       | \x7b7d
 Elixir.LunarFrontiers.App.Events.ConstructionProgressed | \x7b7d
 Elixir.LunarFrontiers.App.Events.GameloopAdvanced       | \x7b7d
 Elixir.LunarFrontiers.App.Events.ConstructionProgressed | \x7b7d
 Elixir.LunarFrontiers.App.Events.ConstructionCompleted  | \x7b7d
 Elixir.LunarFrontiers.App.Events.BuildingSpawned        | \x7b7d
(8 rows)
```

At this point, our event log is persisted and not loss if we restart our application.  
This is not the case of the projections as they are still maintained in the in-memory ETS table. After a restart, we can rebuild our projection using `mix commanded.reset` or a more verbose version:  

```elixir
iex>> :ets.tab2list(:buildings)
[]
iex> Mix.Tasks.Commanded.Reset.run(["--app", "LunarFrontiers.App.Application", "--handler", "LunarFrontiers.App.Projectors.Building"])
Resetting "LunarFrontiers.App.Projectors.Building"
# [...]
iex> :ets.tab2list(:buildings)
[
  {1,
   %{
     complete: 100.0,
     location: 1,
     site_id: 1,
     site_type: 1,
     player_id: 1,
     ready: true
   }}
]
```

## Adding Durable Projections to Lunar Frontiers

### Fixing a Weak Link

Before migrating to a durable projection, we have to fix the [`SystemsTrigger`](./lunar_frontiers//lib/lunar_frontiers/app/event_handlers/systems_trigger.ex) module. It can be promoted as a process manager, but it also violates one of the event sourcing laws.  

> ### Event-Sourcing law: Process Managers Must Not Read from Projections
>
> It can be tempting to just query from a projection in order for a process manager to gather the information it needs to do its job. This is a dangerous temptation that needs to be resisted. Not only are projections managed by other entities, and are consequently subject to schema change (or outright removal), but in eventually consistent systems, projections won't produce reliably consistent results.  
> This is one of the hardest of the laws to follow, and a lot of the arguments for violating it can sound reasonable. Done once, the consequences might seem insignificant, but this pattern permeated throughout an entire codebase can break consistency and, even worse, violate the predictable nature of replays.

So lets replace it with a [`GameLoopManager`](./lunar_frontiers/lib/lunar_frontiers/app/process_managers/).  
Then add a `StartGame` command handler in the [`GameLoop`](./lunar_frontiers/lib/lunar_frontiers/app/aggregates/gameloop.ex) aggregate.  
Next, with the introduction of new events and commands, we need to add `StartGame` command into the [`Router`](./lunar_frontiers/lib/lunar_frontiers/app/router.ex).  
And finally, we register our new `GameLoopManager` into the [`supervisor`](./lunar_frontiers/lib/lunar_frontiers/app/supervisor.ex).

Now we have to drop our event store schema then recreate it:  

```elixir
...> mix event_store.drop
Compiling 13 files (.ex)
Compiling 2 files (.ex)
Generated lunar_frontiers app
The EventStore database has been dropped.
...> mix do event_store.create, event_store.init
The EventStore database has been created.
The EventStore schema already exists.
The EventStore database has been initialized.
```

### Projecting with Redis

Now we'll make our projection durable using a Redis.  
First of all, add a new docker container: `docker run --name elixir-redis -p 6379:6379 -d redis:latest`  

We install [Redix](https://hex.pm/packages/redix) by adding into [mix.exs](./lunar_frontiers/mix.exs):  

```elixir
{:redix, "~> 1.5"}
```

Then we have to declare it into our [`Application`](./lunar_frontiers/lib/lunar_frontiers/application.ex) before rewriting our [`Projector`](./lunar_frontiers/lib/lunar_frontiers/app/projectors/building.ex).

Now we add a [script file](./lunar_frontiers/scripts/single_site.exs) to create and build a new site.  
Run it with the command:  

```elixir
...> iex -S mix run scripts/single_site.exs
```

If we look into our event store, we'll see our new streams:  

```bash
eventstore=# select stream_uuid from streams;
                stream_uuid
-------------------------------------------
 game-0a0cf20c-7114-48e8-bc03-3d9ec397ec3e
 site-9378ff85-a7ae-4739-9fe9-9744d76f44d0
 bldg-9378ff85-a7ae-4739-9fe9-9744d76f44d0
 $all
(4 rows)
```

Then check Redis content:

```bash
...> docker exec -it elixir-redis redis-cli
127.0.0.1:6379> KEYS *
1) "sites:px42"
2) "building:9378ff85-a7ae-4739-9fe9-9744d76f44d0"
127.0.0.1:6379> GET building:9378ff85-a7ae-4739-9fe9-9744d76f44d0
"{\"complete\":100.0,\"location\":1,\"site_id\":\"9378ff85-a7ae-4739-9fe9-9744d76f44d0\",\"site_type\":1,\"player_id\":\"px42\",\"ready\":true}"
```

### Projecting with Ecto

Commanded library also has a plugin for building projectors using Ecto. This makes projector syntax easy to read:  

```elixir
defmodule Projector do
  use Commanded.Projections.Ecto,
    application: MyApp.Application,
    name: "my-projection",
    repo: MyApp.Repo,
    schema_prefix: "my-prefix",
    timeout: :infinity

  project %Event{}, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :my_projection, %MyProjection{...})
  end
end
```

More content available about [Ecto](https://pragprog.com/titles/wmecto/programming-ecto/).
