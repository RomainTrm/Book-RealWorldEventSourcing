# 7. Evolving Event-Sourced Systems

At some point, our application will have to change, in this chapter we explore how to deal with these changes on an immutable events world.  

## Evolving Event Schemas

> ### Event-Sourcing law: Event Schemas are Immutable
>
> Event schemas must never change. Any change to an event schema produces a brand-new event type. This means that each new version of an event is a unique type.  

Imagine an `AccountCreated` event that evolves over time:  

```goat
+------------------+   +------------------+   +------------------+
|  AccountCreated  |   |  AccountCreated2 |   |  AccountCreated3 |
+------------------+   +------------------+   +------------------+
| UserId           |   | UserId           |   | UserId           |
| Name             |   | Name             |   | Name             |
| Address          |   | Address          |   | Address          |
| Email            |   | Email            |   | Email            |
+------------------+   | SubscriptionPlan |   | SubscriptionPlan |
                       +------------------+   | ServiceRegion    |
                                              +------------------+
```

At first glance, it seems to be backward compatible. With some serialization techniques, we can handle all versions as `AccountCreated3` event with some nullable/optional fields. The author makes a case against such compatibility.  

He argues that for an optional field can be seen as a default value, but this assumption comes from outside the event stream. If the code that process these events change, then the default value also change, meaning we've corrupt our system.  

Instead, we should use the *versioning strategy* with explicit and dedicated piece of code for each version of our event.  

Author advice:  

- A change to an event schema produces a new event schema.
- Events that are no longer used aren't deleted: they just stop occurring.
- Avoid the backward compatibility trap by not making assumptions about optional fields.
- We cannot change the past to accommodate new schemas or events.

> Personal note: I have encountered this "event schema should not change, use the *versioning strategy*" dogma many times. I agree, the *versioning strategy* is definitely a technique that you should master, but I disagree this is a default "go to" strategy:  
> In the long run, we're putting ourselves at risk to deal with many versions of the same event, meaning we have to handle them in aggregates, process managers and projectors. This is an exponential growth that doesn't sound sustainable. Hiding previous versions in a backward compatible mechanism isn't a good idea either for the reasons the author gives, but also because we tend to lose track of what's in our event store.  
> When adding or modifying fields, I personally use *events migration* for my event store like any other database (I know, event sourcing purists might by screaming right now). I see two distinct cases:  
>
> - The new field is `null`, meaning there is no value and not an assumption of a default value.  
> - A default value: quite often, when adding a field, we add new use cases, meaning that past events were all handling the same use case.  
>
> If my strategy can't be applied, then I fallback to the *versioning strategy*.

## Evolving Aggregates

There are two types of changes:  

- How it computes its internal state.
- What events are returned for a given command.

Evolving these has no impact the event streams, they must remain unmodified.  

## Evolving Projections and Projectors

Projections are disposable as they're not used by business logic, they're only used as consumer-facing read model. When evolving a projection, we have to rebuild it by replaying the event stream.  

> ### Event-Sourcing law: Different Projectors Cannot Share Projections
>
> Projectors must share nothing with other projectors. They're free to update their own data but can neither read nor write projections managed by other projectors.  

## Evolving Process Managers

*Process managers* rarely evolve in isolation. If we add a new step in our process, this can mean a new command to handle for an *aggregate* and possibly new events to handle for our *process manager* and for some *projectors*.  
Also, we cannot change how the process evolved in the past, if we add a step, this will only apply to new events.  
This can be done by creating a new version of our *process manager*.  

## Evolving Lunar Frontiers

For this exercise, we will only focus on evolving aggregates. We'll merge `Site` and `Building` aggregates into a single `Building` and store construction progress into the *aggregate*. Flow will evolve from:  

`SiteSpawned -> ConstructionProgressed -> ConstructionCompleted -> (command) -> BuildingSpawned`  

to the new process

`BuildingSpawned.V2 -> ConstructionProgressed -> ConstructionCompleted`

As these events already exist in the log, this process should be compatible and not alter the timeline. This also means that the game doesn't need to maintain the `Site`'s projection.  
Note that the `Construction` *process manager* becomes useless as we can directly dispatch `AdvanceConstruction` to the `Building` *aggregate*.  

So, in this refactoring, we will remove the `Site` *aggregate*, the `Construction` *process manager*, create new versions of the commands and events when necessary.  

First, we evolve the [`GameLoopManager`](./lunar_frontiers/lib/lunar_frontiers/app/process_managers/game_loop_manager.ex) for handling the new event and issuing the new command. `Site`'s events are not necessary anymore.  
Then we remove `Site` from the [`Router`](./lunar_frontiers/lib/lunar_frontiers/app/router.ex), we add the new command and `AdvanceConstruction` command to `Building`.  
Finally, we remove the `Construction` *process manager* from the [`supervisor`](./lunar_frontiers/lib/lunar_frontiers/app/supervisor.ex).  

> Personal note: After implementing myself this step, I found several issues in the code example (doesn't even compile), especially in the `Building` *aggregate* code that is not even shown in the book and that mixes `Building` and `ConstructionSite` pieces of code.  

## Migrating Event Streams

Framework solutions to migrate events *in-memory* as they're processed is a dangerous solution as we're at risk to fallback into the backward compatibility trap. Instead, the author suggests migrating events by producing new steams.  
