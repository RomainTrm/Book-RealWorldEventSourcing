# 1. Building Your First Event-Sourced Application

Event-sourcing is all about deriving meaningful state from the *past*. If you apply an *event* that occurred in the *past* to the current state, what you get back is a new state: `f(state, event) = 'state`.  

## Saying "Hello, Procedural World"

Here we build a simple [calculator](./calculator.v0.exs) that takes values and computes a result.  

```elixir
..> iex calculator.v0.exs
iex> Calculator.add(5, 6)
11
iex> Calculator.add(5, 6) |> Calculator.mul(3) |> Calculator.min(1)
32
```

This code does the job. However, in the second command we chain operations and obtain the final result. Intermediate results are lost but we would like to keep them like many calculator apps do.  

## Building a Stateful and Imperative Calculator

First of all, we make a baby step to use a [single function](calculator.v1.exs), operations are passed as command parameters.  

```elixir
..> iex calculator.v1.exs
iex> Calculator.handle_command(%{value: 5}, %{cmd: :add, value: 6})
%{value: 11}
iex> Calculator.handle_command(%{value: 10}, %{cmd: :mul, value: 5})
%{value: 50}
```

So far this is way more code than necessary for such basic operations, but this step will help us.  

## Create Your First Event-Driven Calculator

*Command* is an instruction to do some work, an *event* is a representation of something that happened, a decision made.  
So far, when sending a *command* we received a new state, meaning our code was making a decision and applying it at the same time. Now we [split those roles](calculator.v2.exs), *commands* produce *events* that are then used to derive a new state.  

```elixir
..> iex calculator.v2.exs
iex> evt = Calculator.handle_command(%{value: 5}, %{cmd: :add, value: 6})
%{value: 6, event_type: :value_added}
iex> Calculator.handle_event(%{value: 10}, evt)
%{value: 16}
```

Note that I didn't use the same state for the command handler and the event handler:  

- command handler uses the state to validate the command and make a decision
- event handler uses the state to produce a new state

## Handling Errors by Modeling Failure

The previous version of our calculator can be broken easily:  

```elixir
iex> evt = Calculator.handle_command(%{value: 5}, %{cmd: :div, value: 0})
%{value: 0, event_type: :value_divided}
iex> Calculator.handle_event(%{value: 10}, evt)
** (ArithmeticError) bad argument in arithmetic expression
    calculator.v2.exs:35: Calculator.handle_event/2
    iex:8: (file)
```

So we have to [validate](./calculator.v3.exs) our *commands*. For the seek of the exercise, we also bound our min and max values:  

```elixir
iex> evt = Calculator.handle_command(%{value: 9_500}, %{cmd: :add, value: 650})
%{value: 500, event_type: :value_added}
```

Here we asked for 650 to be added, but as it will exceed our upper limit, the event says only 500 are added to our value.  

When attempting invalid operations like dividing by zero, we get a nice error and no event as a result:  

```elixir
iex> evt = Calculator.handle_command(%{value: 9_500}, %{cmd: :div, value: 0})
%{error: :divide_failed}
```

> ## Event-Sourcing law: All Events are Immutable and Past Tense
>
> Every event represents something that actually happened. An event cannot be modified and always refers to something that took place. Modeling the absence of a thing or a thing that didn't actually occur may often seem like a good idea, but doing so can confuse both developers and event processors. Remember that if an error didn't result in some immutable thing happening, it shouldn't be modeled as an event.

Now we chain commands and get a result:  

```elixir
iex> initial = %{value: 0}
%{value: 0}
iex> cmd = [
...> %{cmd: :add, value: 10},
...> %{cmd: :add, value: 50},
...> %{cmd: :div, value: 0},
...> %{cmd: :add, value: 2}]
[
  %{value: 10, cmd: :add},
  %{value: 50, cmd: :add},
  %{value: 0, cmd: :div},
  %{value: 2, cmd: :add}
]
iex> cmd |> List.foldl(initial,
...> fn cmd, state -> event = Calculator.handle_command(state, cmd)
...>                  Calculator.handle_event(state, event) end)
%{value: 62}
```

Note that the result of the divide by 0 as been ignored. We've produced a "failure event" that is not applied to the state, thanks to our default event handler:  

```elixir
  def handle_event(%{value: _val} = state, _event) do
    state
  end
```

> ## Event-Sourcing law: Applying a Failure Event Must Always Return the Previous State
>
> Any attempt to apply a bad, unexpected, or explicitly modeled failure event to an existing state must always return the existing state. Failure events should only indicate that a failed thing occurred in the past, not command rejections.

## Working with Event-Sourcing Aggregates

An event-sourcing aggregate has the following required characteristics:  

- Validates incoming commands and returns one or more events
- Applies events to state to produce new state
- Application of events and commands is pure and referentially transparent
