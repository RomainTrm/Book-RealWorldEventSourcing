# 2. Separating Read and Write Models

## Justifying Model Separation

With event-sourcing, data exists within an event stream. This means if we want to query information, we should go through the stream and find the data. This *shape* of the model is highly impractical at query time.  
*Readmodels* are all about pregenerated data available for specific queries with a goal of a fixed execution time *O(1)*.

## Building Your First Projection

We'll build a bank ledger account *projector* that takes events and store data in a readmodel.  
The projector API should look like this:  

```elixir
iex> Projector.apply_event(%{event_type: :amount_deposited, account_number: "ABC", value: 12})
:ok
iex> Projector.lookup_balance("ABC")
{:ok, 12}
```

The author suggests that the `apply_event` function should not accept a key separated from the event. His point here is to avoid accidentally modifying the wrong projection. I totally get his point here, though, I don't think this key should always be stored in the event's payload: an event is inside an event stream with an associated unique id, this id must be provided to the *projector* with the event.  

> ## Event-Sourcing law: All Data Required for a Projection Must Be on the Events
>
> The event is the *only* source of truth. If code allows a different piece of information to be supplied as a parameter that contradicts information on the event, you can corrupt an entire event stream. As such, all keys, metadata, and payload data must come from events and nowhere else. This is often one of the hardest laws to follow but the penalties for breaking it can be subtle and disastrous.

When looking at our [projector](balance_projector.exs), there are several things that are worth mentioning:  

- We store accounts in a named `Registry`: `Registry.AccountProjectors`
- Every account has a dedicated server
- When handling the first event of a new account, a new server is spawned
- Querying an unknown account will return an error

```elixir
iex> {:ok, _} = Registry.start_link(keys: :unique, name: Registry.AccountProjectors)
{:ok, #PID<0.105.0>}
iex> c("balance_projector.exs")
[Projector]
iex> Projector.apply_event(%{event_type: :amount_deposited, account_number: "ABC", value: 12})

09:39:27.046 [debug] Attempt to apply event to non-existent account, starting projector
:ok
iex> Projector.apply_event(%{event_type: :amount_deposited, account_number: "ABC", value: 30})
:ok
iex> Projector.lookup_balance("ABC")
{:ok, 42}
iex> Projector.lookup_balance("XXX")
{:error, :unkown_account}
```

> Note: An aggregate's state is internal and private, readmodel are designed to be shared and accessible to any consumer.  

## Projecting a Leaderboard

With [this projector](leaderboard_projector.exs), we want to maintain a leaderboard of the best zombie slayers.  
Each player must be able to get his current score, we should also be able to query the top 10 players.  
The code remains straightforward.  

## Projecting Advanced Leaderboards

Now we want to evolve our leaderboard to show the top 10 players in the current week.  
It can be tempting to access the system clock to get a ranking in the last 7 days. But quite often, these kinds of rankings are established on a fixed week instead of a sliding window.

This gets this problem easy to solve, the solution is to handle a new event that marks the end of the week:  

```elixir
def handle_cast({:handle_event, %{event_type: :week_completed}}, _state) do
  {:reply, %{scores: %{}, top10: []}}
end
```
