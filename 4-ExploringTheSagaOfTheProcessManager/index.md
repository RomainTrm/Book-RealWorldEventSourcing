# 4. Exploring the Saga of the Process Manager

In this chapter we explore the last fundamental building block: *process managers*. It is used to manage statefull long-running processes. By long, we mean a process that requires multiple commands and events to complete.  

From the behavior perspective, a process manager is the inverse of an aggregate: it consumes events and return commands.  

## Modeling a process

An event must start, some events may have advance, and one event must stop the process.  

Here are some questions to ask ourselves in order to choose if we need a process manager or not:  

- Does this flow have a discrete beginning, middle, and end?
- Does this flow take action in response to events?
- Is the state of this flow meaningful beyond simple "started" and "completed" events?
- Is this flow potentially repeatable multiple times for a single entity?

If we answer yes to at least one of these questions, then we probably want a process manager.  
Sketching our flow with boxes and arrows is a little initial investment that can improve our understanding of the process we're modeling.  

## Creating a Simple Process Manager

We're going to build a process manager that advances by handling a batch of files, the flow goes as follows:  

1. A batch is created via the `create_batch` command.
2. The `file batch` aggregate emits a `batch_created` event.
3. The `process manager` creates and dispatches one command per file.
4. The `file batch` aggregate emits a file processing requested event, which is picked by a notifier/gateways.
5. Once file is processed, an injector/gateways dispatches a `file_processed` event.  
6. The `process manager` updates its internal state.

> ### Event-Sourcing law: Work Is a Side Effect
>
> A frequently asked question in new event sourcing projects is "where does the work happen?" Aggregates aren't allowed to perform side effects or read from external data. Process managers aren't allowed to perform side effects or read from external data. Projectors can create external data, but they can't perform "work" either.
>
> If you follow the rule that work is a side effect, things may be easier to understand. If work is a mutation of the world outside the event-sourced system, the work is a side effect, and side effects are only allowed through gateways. The core primitives of aggregates, projector, and process managers must never do work.

Here's the [implementation](./process_manager.exs) of the process manager. It starts with the `:idle` status and, after receiving the `batch_created` event, switched to `:processing` and keep updating its status on `file_processed` events.

```elixir
iex> c("process_manager.exs")
[Batch.ProcessManager]
iex> {:ok, pid} = Batch.ProcessManager.start_link(%{id: "batch1"})
{:ok, #PID<0.121.0>}
iex> GenServer.call(pid, {:process_event, %{event_type: :batch_created, files: ["f1", "f2", "f3"]}})
[
  %{file: "f1", command_type: :process_file},
  %{file: "f2", command_type: :process_file},
  %{file: "f3", command_type: :process_file}
]
iex> GenServer.call(pid, {:process_event, %{event_type: :file_processed, file: %{id: "f1", status: :success}}})
[]
iex> GenServer.call(pid, {:process_event, %{event_type: :file_processed, file: %{id: "f2", status: :success}}})
[]
iex> :sys.get_state(pid)
%{
  id: "batch1",
  status: :pending,
  files: %{"f1" => :success, "f2" => :success, "f3" => :peding}
}
iex> GenServer.call(pid, {:process_event, %{event_type: :file_processed, file: %{id: "f3", status: :success}}})
[]
iex> :sys.get_state(pid)
%{
  id: "batch1",
  status: :success,
  files: %{"f1" => :success, "f2" => :success, "f3" => :success}
}
```

Once completed, we can choose to delete or cleanup the process manager state, or we can choose to keep it for historical queries. In such case, we need a dedicated projector.  

> ### Event-Sourcing law: All Projections Must Stem from Events
>
> Every piece of data produced by any projector *must* stem from at least one event. You cannot ever create a projection data based on information from outside the event stream. Doing so would violate other event sourcing laws and ruin your system's ability to participate in replays.

At this point, it can be tempting to add more state and managing other activities in our process manager.

> ### Event-Sourcing law: Never Manage More than One Flow per Process Manager
>
> Each process manager is responsible for a single, isolated process. Its internal state represents an instance of that managed flow (for example, "Order 421", "Batch 73", or "New User Provisioning for User ABC"). As tempting as it may be to create a process manager for "orders" or "users", never lump multiple process flows into a single manager. Doing so generally means the failure of one flow can cascade out throughout the system. Keeping flows separate also avoids accidentally corrupting one process state with that of another.

## Building an Order Fulfillment Process Manager

Now we'll build a realistic and capable process manager.  
The following diagram describes the process

```goat
+----------------+                    +------------+         +---------+
|  Order Process |      Reserve/      | Stock Unit |         | Payment |
|    Manager     +----- Release/ ---->+ Aggregate  |         | Gateway |    
+------+---------+     Remove Qty     +------------+         +----+----+
       |                                                          ^          
       |                                +----------+              |
   Ship order    Shipping Initiated     | Shipping |       Payment Approved  
       |          Order Canceled    --->+ Gateway  |       Payment Declined 
       |        /                       +----------+         Refund Issued
       v       /                                                  |
+------+----+ /                                              +----+----+
|    Order  |/                     Pay Details Updated       | Payment |
| Aggregate +---------------------   Order Created     ----->+ Gateway |
+------+----+                        Order Canceled          +---------+
       ^
       |
    Create Order
    Change Pay Details
    Cancel Order

```

Now we can derive the properties of the order fulfillment process manager. For a given event, we must yield a command:  

- `f(order_created) -> reserve_quantity`
- `f(order_canceled) -> release_quantity`
- `f(order_shipped) -> remove_quantity`
- `f(payment_approved) -> ship_order`
- `f(payment_declined) -> nil`
- `f(payment_details_updated) -> ship_order`

The corresponding phases are:  

- Start - `order_created`
- Advance - `payment_approved`, `payment_declined`, `payment_details_updated`
- Stop - `order_shipped`, `order_canceled`

*Payment* and *Shipping* gateways are notifier/injector hybrids that manage interactions with external systems (where the "work" is done).

The code is available in [`OrderFulfillment.ProcessManager`](./fulfillment_pm.exs).

First, we can start our process manager and initiate our created order.

```elixir
iex> {:ok, pid} = OrderFulfillment.ProcessManager.start_link(%{id: 12})
{:ok, #PID<0.119.0>}
iex> GenServer.call(pid, {:process_event,
...>   %{event_type: :order_created, items: [
...>     %{sku: "WIDGETONE", quantity: 5},
...>     %{sku: "SUPERITEM", quantity: 4}
...>   ]
...> }})
[
  %{
    aggregate: :stock_unit,
    command_type: :reserve_quantity,
    quantity: 5,
    sku: "WIDGETONE"
  },
  %{
    aggregate: :stock_unit,
    command_type: :reserve_quantity,
    quantity: 4,
    sku: "SUPERITEM"
  }
]
```

We get commands to dispatch as result. Now we can declare payment has been approved.  

```elixir
iex> GenServer.call(pid, {:process_event,
...>   %{event_type: :payment_approved, order_id: 12}
...> })
[%{aggregate: :order, command_type: :ship_order, order_id: 12}]
iex> :sys.get_state(pid)
%{
  id: 12,
  status: :shipping,
  items: [%{quantity: 5, sku: "WIDGETONE"}, %{quantity: 4, sku: "SUPERITEM"}]
}
```

Note that process managers are command-emitting state machines.  
Now, we simulate an error-free path where the order is shipped without incident.  

```elixir
iex> GenServer.call(pid, {:process_event,
...>   %{event_type: :order_shipped, order_id: 12}
...> })
[
  %{
    aggregate: :stock_unit,
    command_type: :remove_quantity,
    sku: "WIDGETONE",
    quanitty: 5
  },
  %{
    aggregate: :stock_unit,
    command_type: :remove_quantity,
    sku: "SUPERITEM",
    quanitty: 4
  }
]
iex> Process.alive?(pid)
false
```

## Building a User Provisioning Process Manager

As an exercise, we'll build a new user provisioning process. Once the new user is provisioned, two things need to happen:  

- Provision a user database - Each user in this application gets their own database, provisioned during the initial setup phase.
- Generate avatar - Each user gets an avatar generated from their metadata (done by a worker).

```goat
                                                                    +-------------------+
                                                                    | Avatar Generation |
                                        / 3a. Avatar Gen started -->+     Notifier      |
                     +----------------+/                            +-------------------+
-- 1. Create User -->+ User Aggregate +               
                     +--+----------+--+\                            +------------------+
                        |          ^    \ 3b. User DB        ------>+ User DB Notifier |
                        |          |      Provision Started         +------------------+
                        |          |
                        |          |
                2. New User     2a. Provision UserDB
                   Created      2b. Generate Avatar
                        |          |
                        |          |                                +------------------+
                        v          |      / 4a. DB Provision ------>+ User DB Injector |
                    +---+----------+----+/    Pass/Fail             +------------------+
                    | User Provisioning +  
                    | Process Manager   +  
                    +-------------------+\                          +-------------------+
                                          \ 4b. Avatar Gen -------->+ Avatar Generation |
                                              Pass/Fail             |   Injector        |
                                                                    +-------------------+
```

Some major changes in the modeling compared to the previous use case:  

- Gateway has been split as notifiers and injectors.
- Failures are explicitly modeled. A failure means something that failed, not a command rejected by the aggregate.

*User* Aggregate:  

1. Accepts the `CreateUser` command.
2. Emits the `NewUserCreated` event - an indication of a new, empty aggregate and *not* an indication of process completion.
3. Accepts and validates the ``ProvisionUserDb` and `GenerateAvatar` commands.
4. Emits `AvatarGenerationStarted` and `DbProvisioningStarted` events.

*User Provisioning* Process Manager:

1. Accepts the `DbProvisioningPassed` and `DbProvisioningFailed` events.
2. Accepts the `AvatarGenerationPassed` and `AvatarGenerationFailed` events.
3. When both result events are received, emits either `UserProvisioningSucceeded` or `UserProvisioningFailed` events.  

> Note: The author says that *Process Managers* sends commands, then here, without explanation, it says it can return events like an injector.  
> Usually, in such cases I send a command to the aggregate saying "I notify you that something happened" and it emits events.

**Solution is not provided**, following content is my own solution.  

If we derive the properties:  

- `f(new_user_created) -> provision_user_db,generate_avatar`
- `f(avatar_generation_started) -> nil`
- `f(db_provisioning_started) -> nil`
- `f(db_provisioning_passed) -> nil OR notify_user_provisioning_succeeded when avatar_generation_passed received`
- `f(db_provisioning_fail) -> nil OR notify_user_provisioning_failed when avatar_generation_xxxx received`
- `f(avatar_generation_passed) -> nil OR notify_user_provisioning_succeeded when db_provisioning_passed received`
- `f(avatar_generation_fail) -> nil OR notify_user_provisioning_failed when db_provisioning_xxxx received`
- `f(user_provisioning_succeeded) -> nil`
- `f(user_provisioning_failed) -> nil`

The corresponding phases are:  

- Start - `new_user_created`
- Advance - `avatar_generation_passed`, `avatar_generation_fail`, `db_provisioning_passed`, `db_provisioning_fail`
- Stop - `user_provisioning_succeeded`, `user_provisioning_failed`

The code is available in [`UserProvisioning.ProcessManager`](./user_provisioning_pm.exs).

```elixir
iex> {:ok, pid} = UserProvisioning.ProcessManager.start_link(%{user_id: 5})
{:ok, #PID<0.112.0>}
iex> :sys.get_state(pid)
%{
  status: :idle,
  user_id: 5,
  avatar_generation_status: :unknown,
  db_provisioning_status: :unknown
}
iex> GenServer.call(pid, {:process_event, %{event_type: :new_user_created}})
[
  %{aggregate: :user, user_id: 5, command_type: :provision_user_db},
  %{aggregate: :user, user_id: 5, command_type: :generate_avatar}
]
iex> GenServer.call(pid, {:process_event, %{event_type: :avatar_generation_started}})
[]
iex> GenServer.call(pid, {:process_event, %{event_type: :db_provisioning_started}})
[]
iex> :sys.get_state(pid)
%{
  status: :processing,
  user_id: 5,
  avatar_generation_status: :unknown,
  db_provisioning_status: :unknown
}
iex> GenServer.call(pid, {:process_event, %{event_type: :db_provisioning_passed}})
[]
iex> :sys.get_state(pid)
%{
  status: :processing,
  user_id: 5,
  avatar_generation_status: :unknown,
  db_provisioning_status: :passed
}
iex> GenServer.call(pid, {:process_event, %{event_type: :avatar_generation_passed}})
[
  %{
    aggregate: :user,
    user_id: 5,
    command_type: :notify_user_provisioning_succeeded
  }
]
iex> :sys.get_state(pid)
%{
  status: :processing,
  user_id: 5,
  avatar_generation_status: :passed,
  db_provisioning_status: :passed
}
iex> GenServer.call(pid, {:process_event, %{event_type: :user_provisioning_succeeded}})
[]
iex> Process.alive?(pid)
false
```
