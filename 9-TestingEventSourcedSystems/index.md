# 9. Testing Event-Sourced Systems

Testing event-sourced applications *should* be as simple as testing pure functions.

## Testing Aggregates

Aggregates accept commands and, depending on their state, return 0 to n events:  

`f(state, command) = e1..en`

External values like the system clock must be provided by the command.  
Here's a (simplified) Elixir test of an aggregate:  

```elixir
defmodule AggregateTest do
  use ExUnit.Case

  test "produces overdraft event on negative balance" do
    state = %{balance: 50, account_number: "B00100"}
    cmd = %Bank.WithdrawCommand{account_number: "B00100", amount: 100}

    assert BankAggregate.handle_command(state, cmd) == [
      %{
        event_type: :amount_withdrawn,
        amount: 100,
        account_number: "B00100",
        effective_balance: -50
      },
      %{
        event_type: :overdraft,
        account_number: "B00100",
        overage: 50
      }
    ]
  end
end
```

Though, we don't want to write tests for internal state `f(state, event) = state'`.

> ### Event-Sourcing law: Never Test Internal State
>
> Internal state of aggregates and process managers can change in form and purpose. Tests should supply input and assert output without enforcing or asserting the shape of internal state.

To ensure the correctness of the internal state, we test the aggregate as a black box: we provide a sequence of commands (or a stream of events) and we rebuild the state until we can test the desired command. If we modify our previous test:  

```elixir
defmodule AggregateTest do
  use ExUnit.Case

  test "produces overdraft event on negative balance" do
    initial_state = BankAggregate.new("B00100")

    events = BankAggregate.handle_command(
        initial_state,
        %Bank.Desposit{account_number: "B00100", amount: 50}
    )

    state = BankAggregate.apply_events(initial_state, events)
    cmd = %Bank.WithdrawCommand{account_number: "B00100", amount: 100}

    assert BankAggregate.handle_command(state, cmd) == [
      %{
        event_type: :amount_withdrawn,
        amount: 100,
        account_number: "B00100",
        effective_balance: -50
      },
      %{
        event_type: :overdraft,
        account_number: "B00100",
        overage: 50
      }
    ]
  end
end
```

With such strategy, we can modify the aggregate's internal state without breaking the tests.

## Testing Projectors

*Projectors* produce external state. As they're part of the public API of our application, we want to assert they have the correct shape and values.  
As writing into the data store is a side effect, we want to focus here on the pure transformation part `f(projection, event) = projection'`.  
Here's a test example:  

```elixir
defmodule ProjectorTest do
  use ExUnit.Case

  test "projector add deposits" do
    initial_projection = BankAccountProjection.empty()
    evts = [
      %{event_type: :account_created, account_number: "B00100"},
      %{event_type: :amount_deposited, account_number: "B00100", amount: 500}
    ]
  
    projection = BankAccountProjection.handle_events(initial_projection, evts)
    assert projection = %{account_number: "B00100", balance: 500}
  end
end
```

Requiring a projector to have access to previous versions can create unnecessary burden on the system and consistency problems.  
The easiest way to solve this is to move computations into the aggregate and send result through events.  
If we modify our previous example, the event stream should look like this:  

```elixir
evts = [
  %{event_type: :account_created, account_number: "B00100"},
  %{event_type: :amount_deposited, account_number: "B00100", amount: 500, effective_balance: 500}
]
end
```

By adding the `effective_balance`, the projector doesn't need the previous version of itself to calculate the value.  
Note that such isolation "purity" isn't always possible or practical. For instance, for building our leaderboard on [chapter 2](../2-SeparatingReadAndWriteModels/index.md), it is probably as more convenient to reload previous state than adding a dedicated aggregate.

## Testing Process Managers

Process managers look like aggregates expect they receive events and return commands:  

`f(state, event) = c0..cn`

Here's a test example:  

```elixir
defmodule ConstructionProcessTest do
  use ExUnit.Case

  test "process manager spawns buildings" do
    empty_state = %{}
    event = %{event_type: :construction_completed, site_x: 0, ...}

    assert ConstructionManager.handle_event(empty_state, event) == [
        %SpawnBuilding{x: 0, ...}
    ]
  end
end
```

As it is aggregate's responsibility to validate a command, we should only expect tests on process advancement and termination.

## Using Automated and Acceptance Testing

As we've tested individual building blocks, now we want to test the overall choreography.  
What we are looking for is logic flaws where we don't produce the desire output under some flow of events and commands. The easiest way to do it is by running a sequence of commands (and/or external events) and then check the system's state through projectors.  
