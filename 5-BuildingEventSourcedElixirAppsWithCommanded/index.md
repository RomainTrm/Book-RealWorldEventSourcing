# 5. Building Event-Sourced Elixir Apps with Commanded

In this chapter, we'll build an application using all the building blocks we've covered so far and the [Commanded](https://hex.pm/packages/commanded) library.  

## Introducing Lunar Frontiers

It's a game about terraforming moons with robots that must be programmed by players.  
Players will write code, upload it into machines and "watch" the results. By "watch" we mean a text adventure.  

### Embracing the Game Loop

Underneath every game we can find a simple `while` loop: during each iteration, the various elements of the game are adjusted and ultimately a *frame* is rendered. In a traditional game, a frame is an image generated once per iteration of the loop.  

In our event-sourced implementation, we'll use an `injector` as a way to trigger a "loop tick".

## Creating the First Flow

The simplest flow is the creation of a new building. A player plants a construction site on a suitable place, the construction then advances on each tick until it finishes.  

```goat

                                                   Delete Site
                                       +---------- Spawn Building --------------+
                                       |                                        |
                                       v                                        |
                             +---------+---------+     Construction     +-------+---------+
          Spawn Site         | Construction Site +----  Completed   --->+    Building     |
--- Advance Construction --->+     Aggregate     +---                   |    Aggregate    |
                             +---------+---------+   \                  +-----------------+
                                       |              \
                                       |               \
                            Construction Progressed     \
                            Construction Completed       \
                                       |              Construction Completed
                                       v                   \
                             +---------+---------+          \          +-------------------+
                             | Construction Site |            -------->+ Construction Site |
                             |     Projector     |                     |  Process Manager  |
                             +-------------------+                     +-------------------+
```

In this flow, we have both a construction site and a building. A construction progress can halt when we run out of resources and resume when new resources are available. A construction site can be attacked and lose progress or be destroyed.  

### Creating the Consturction Site Aggregate

With the flow, we can shape the following commands:  

- `f(spawn_site) -> site_spawned`
- `f(advance_construction) -> construction_progressed, construction_completed`

Should the construction site aggregate emit `construction_completed` or the process manager? Process managers must not emit events. It is also obvious that the aggregate is the authority of record with regard to its own completion status.  

See `ConstructionSite` aggregate [sources](./lunar_frontiers/lib/lunar_frontiers/app/aggregates/construction_site.ex).  

We have to familiar Commanded required callbacks:  

- `execute`: this process a command and returns one or more events. The use `Multi.new()` produces multiple events, including an optional `construction_completed`.
- `apply`: this accepts an event and returns the updated state.  

### Creating the Building Aggregate

See `Building` aggregate [source code](./lunar_frontiers/lib/lunar_frontiers/app/aggregates/building.ex).  
Code is simple, the `Building` can only do one thing so far: spawn.  

### Creating the Game Loop Aggregate

Instead of using an injector for the gameloop as previously mentioned, we'll introduce a dedicated aggregate.  
This leaves an opportunity to introduce some advancement validation: we can choose to go for another tick or declare the game as completed.

See the [code](./lunar_frontiers/lib/lunar_frontiers/app/aggregates/gameloop.ex).  

### Managing the Consturction Process

See the [code](./lunar_frontiers/lib/lunar_frontiers/app/process_managers/construction.ex).  
`interested?` function tells Commanded if an event interest the ProcessManager and also for which phase of the process. In previous chapter, we've defined *start*, *advance* and *stop* process, here the corresponding atoms are `:start`, `continue` and `:stop`.  

The `handle` function allows the ProcessManager to convert an event into a command. We don't need an `handle` function for every interested events. The process manager silently performs a no-op for unhandled events.  

### Routing Commands and Events

Last thing we need to do is routing commands and events, see the `Router` [source code](./lunar_frontiers/lib/lunar_frontiers/app/router.ex).  

The `identify` and `dispatch` macros are a shortcuts for explicitly defining route rules.  

We also have a `SystemsTrigger` [event handler](./lunar_frontiers/lib/lunar_frontiers/app/event_handlers/systems_trigger.ex).  
It takes an event and returns a new command to trigger the next game loop.  
An event handler that emits a command and is not a process manager is a specialized type form of gateway called *multiplexer*.

## Playing the Game

```elixir
...> iex -S mix
11:03:10.062 [debug] LunarFrontiers.App.ProcessManagers.Construction has successfully subscribed to event store
11:03:10.062 [debug] LunarFrontiers.App.Projectors.Building has successfully subscribed to event store
11:03:10.062 [debug] LunarFrontiers.App.EventHandlers.SystemsTrigger has successfully subscribed to event store

# Setup the game and move to tick 1
iex> LunarFrontiers.App.Application.dispatch(
...>   %LunarFrontiers.App.Commands.AdvanceGameloop{game_id: 1, tick: 1})

11:04:41.912 [debug] Locating aggregate process for `LunarFrontiers.App.Aggregates.Gameloop` with UUID "game-1"
11:04:41.949 [debug] LunarFrontiers.App.Aggregates.Gameloop<game-1@0> executing command: %LunarFrontiers.App.Commands.AdvanceGameloop{game_id: 1, tick: 1}
11:04:42.017 [debug] LunarFrontiers.App.ProcessManagers.Construction received 1 event(s)

11:04:42.028 [debug] LunarFrontiers.App.Projectors.Building received events: [%Commanded.EventStore.RecordedEvent{event_id: "8792d41a-65f5-4a41-ab63-ea34d93aeab6", event_number: 1, stream_id: "game-1", stream_version: 1, causation_id: "8437d178-48f9-40ea-939d-7bc159b92893", correlation_id: "34177d97-faba-454f-b9c4-ca2c7fe0b837", event_type: "Elixir.LunarFrontiers.App.Events.GameloopAdvanced", data: %LunarFrontiers.App.Events.GameloopAdvanced{game_id: 1, tick: 1}, created_at: ~U[2025-11-19 10:04:41.967000Z], metadata: %{}}]

11:04:42.028 [debug] LunarFrontiers.App.EventHandlers.SystemsTrigger received events: [%Commanded.EventStore.RecordedEvent{event_id: "8792d41a-65f5-4a41-ab63-ea34d93aeab6", event_number: 1, stream_id: "game-1", stream_version: 1, causation_id: "8437d178-48f9-40ea-939d-7bc159b92893", correlation_id: "34177d97-faba-454f-b9c4-ca2c7fe0b837", event_type: "Elixir.LunarFrontiers.App.Events.GameloopAdvanced", data: %LunarFrontiers.App.Events.GameloopAdvanced{game_id: 1, tick: 1}, created_at: ~U[2025-11-19 10:04:41.967000Z], metadata: %{}}]

11:04:42.032 [debug] LunarFrontiers.App.Aggregates.Gameloop<game-1@1> received events: [%Commanded.EventStore.RecordedEvent{event_id: "8792d41a-65f5-4a41-ab63-ea34d93aeab6", event_number: 1, stream_id: "game-1", stream_version: 1, causation_id: "8437d178-48f9-40ea-939d-7bc159b92893", correlation_id: "34177d97-faba-454f-b9c4-ca2c7fe0b837", event_type: "Elixir.LunarFrontiers.App.Events.GameloopAdvanced", data: %LunarFrontiers.App.Events.GameloopAdvanced{game_id: 1, tick: 1}, created_at: ~U[2025-11-19 10:04:41.967000Z], metadata: %{}}]
:ok

11:04:42.041 [debug] LunarFrontiers.App.Projectors.Building confirming receipt of event #1
11:04:42.041 [debug] LunarFrontiers.App.EventHandlers.SystemsTrigger confirming receipt of event #1
11:04:42.042 [debug] LunarFrontiers.App.ProcessManagers.Construction is not interested in event 1 ("game-1"@1)
11:04:42.042 [debug] LunarFrontiers.App.ProcessManagers.Construction confirming receipt of event: 1

# Spawn a new site
iex> LunarFrontiers.App.Application.dispatch(
...>   %LunarFrontiers.App.Commands.SpawnSite{
...>     completion_ticks: 2, location: 1, player_id: 1,
...>     site_id: 1, site_type: 1, tick: 1
...>   })

11:08:14.407 [debug] Locating aggregate process for `LunarFrontiers.App.Aggregates.ConstructionSite` with UUID "site-1"

11:08:14.413 [debug] LunarFrontiers.App.Aggregates.ConstructionSite<site-1@0> executing command: %LunarFrontiers.App.Commands.SpawnSite{site_id: 1, player_id: 1, site_type: 1, completion_ticks: 2, location: 1, tick: 1}
# ...

# Now we advance the game loop twice more
iex> LunarFrontiers.App.Application.dispatch(
...>   %LunarFrontiers.App.Commands.AdvanceGameloop{
...>     game_id: 1, tick: 2
...>   })
### ...
iex> LunarFrontiers.App.Application.dispatch(
...>   %LunarFrontiers.App.Commands.AdvanceGameloop{
...>     game_id: 1, tick: 3
...>   })
### Our building is now built
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
iex> :ets.tab2list(:sites)
[]
```
