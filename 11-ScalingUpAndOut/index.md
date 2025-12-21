# 11. Scaling Up and Out

Scaling an application from our local development environment out to a redundant, geographic optimized location infrastructure is complex.  
In this chapter we'll explore various scenarios and see when we should implement things ourselves and when to rely on existing frameworks or libraries.  

## Reading Your Writes

When using several instances of our application, we often have a main instance and some local instances. Local instances forward their events to the main instance, that forward in return its projections.  

This means we introduce some latency in our system and local projections are now eventually consistent. This leads to the following type of scenarios that break our monolithic assumptions about data:  

1. The user interacts with a web application cached close to their location.
2. Their actions result in the production of a new event.
3. The event propagates to the cluster leader.
4. The user reads data from the edge-local projection replica.
5. The newly updated projection replicates out from the leader to the edge.

If inconsistent read is harmless and doesn't lead users to bad decisions, then we should embrace it and not bother trying to solve this.  

One naive solution is "wait for my writes". Basically, our local projection should know the current version of a projection at the time when events are emitted, and wait until this version has been increased by the main instance. Note that in reality we're waiting for anyone's changes, there is no guarantee that the version bump is the result of our events.  

Another solution is to apply our changes locally and then make a decision when data comes down from the leader (replace, merge, ...). In such cases, we my look at some heavyweight solutions like *[Conflict-Free Replicated Data Types](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type) (CRDTs*). Rather than implementing these algorithms by ourselves, we should have a look to solutions like Redis or Riak.  

## Preparing for Disorder

In distributed systems, two users can interact with the same resource at the same time from different origins. In such case, we can't predict we order in which commands or events will be processed.  

We should have a look at our aggregates and process managers. Could they produce different results based on a different ordering of events?  

The "easiest" solution is to design our system in a way that events ordering doesn't matter. For example, the balance of your bank account is not impacted by the order of deposits and withdrawals.  

If the order matters, then try to delegate this responsibility to the event store or the message broker. Tools like NATS, RabbitMQ, Cassandra, Event Store, Kafka, etc. handle global ordering and consistency in a much better way than we'll do.  

Another alternative to fixed ordering is using the ideas of *correlation* and *causation*. The idea is to reference an event that *caused* another event. This can be used by projectors to reconciliate events that arrive out of order. When we need to know that two events are related but their order doesn't matter, then we use *correlation*.  

## Preventing Duplicate Processing

This message brokers, we often have to choose between two strategies: *at-least-once* processing or *at-most-once*. Some systems also provide a third *exactly-once* strategy.  

*At-least-once* means we're guaranteed to get the event, but we could also get copies. Some systems assign unique ID to events, so we can track these IDs and remove duplicates. In other products, a configurable "duplicate window" allow the broker to purge messages that are identical to a previously received message. This strategy can be useful when our system can produce the same event several times with different IDs.

*At-most-once* gives us guarantee that we'll not receive duplicates, but we can't be sure that the message will be delivered. This can be a convenient solution when clients are publishing events often. In such case, missing an event isn't an issue as long as the forthcoming events correct the inconsistency.  

## Event Sourcing at Scale with NATS

NATS is a universal connectivity and messaging system. It also supports persistent, replicated streams, which makes it perfect for building event-sourced applications.  

NATS streams (which are part of the JetStream feature) are powerfull tool. They allow us to capture all traffic sent to a set of subjects and then create applications on top of that.  

First, we create a new stream:  

```bash
...> docker exec -it realworldeventsourcing-nats-cli-1 nats stream create
? Stream Name EVENTS
? Subjects lfgheroes.events.*
? Storage file
? Replication 1
? Retention Policy Limits
? Discard Policy Old
? Stream Messages Limit -1
? Per Subject Messages Limit -1
? Total Stream Size -1
? Message TTL -1
? Max Message Size -1
? Duplicate tracking time window 2m0s
? Allow message Roll-ups No
? Allow message deletion Yes
? Allow purging subjects or the entire stream Yes
Stream EVENTS was created

Information for Stream EVENTS created 2025-12-24 09:04:29

                Subjects: lfgheroes.events.*
                Replicas: 1
                 Storage: File

Options:

               Retention: Limits
         Acknowledgments: true
          Discard Policy: Old
        Duplicate Window: 2m0s
              Direct Get: true
    Allows Batch Publish: false
         Allows Counters: false
       Allows Msg Delete: true
  Allows Per-Message TTL: false
            Allows Purge: true
        Allows Schedules: false
          Allows Rollups: false

Limits:

        Maximum Messages: unlimited
     Maximum Per Subject: unlimited
           Maximum Bytes: unlimited
             Maximum Age: unlimited
    Maximum Message Size: unlimited
       Maximum Consumers: unlimited

State:

            Host Version: 2.14.0-dev
      Required API Level: 0 hosted at level 2
                Messages: 0
                   Bytes: 0 B
          First Sequence: 0
           Last Sequence: 0
        Active Consumers: 0
```

We allow message deletion/stream purging here, this is only for development and experimentations, this should not be possible in a production environment.  

Now let's add a message:  

```bash
...> docker exec -it realworldeventsourcing-nats-cli-1 nats req lfgheroes.events.test_happened '{"hello":"world"}'
09:13:34 Sending request on "lfgheroes.events.test_happened"
09:13:34 Received with rtt 5.156944ms
{"stream":"EVENTS","seq":1}

...> docker exec -it realworldeventsourcing-nats-cli-1 nats stream view EVENTS
[1] Subject: lfgheroes.events.test_happened Received: 2025-12-24 09:13:34
{hello:world}

09:14:28 Reached apparent end of data
```

Now we add a consumer:  

```bash
...> docker exec -it realworldeventsourcing-nats-cli-1 nats consumer create
? Select a Stream EVENTS
? Consumer name TEST_MONITOR
? Delivery target (empty for Pull Consumers)
? Start policy (all, new, last, subject, 1h, msg sequence) all
? Acknowledgment policy explicit
? Replay policy instant
? Filter Stream by subjects (blank for all) lfgheroes.events.test_happened
? Maximum Allowed Deliveries -1
? Maximum Acknowledgments Pending 0
? Deliver headers only without bodies No
? Add a Retry Backoff Policy No
Information for Consumer EVENTS > TEST_MONITOR created 2025-12-24 09:17:27

Configuration:

                    Name: TEST_MONITOR
               Pull Mode: true
          Filter Subject: lfgheroes.events.test_happened
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 30.00s
           Replay Policy: Instant
         Max Ack Pending: 1,000
       Max Waiting Pulls: 512

State:

            Host Version: 2.14.0-dev
      Required API Level: 0 hosted at level 2
  Last Delivered Message: Consumer sequence: 0 Stream sequence: 0
    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0
        Outstanding Acks: 0 out of maximum 1,000
    Redelivered Messages: 0
    Unprocessed Messages: 1
           Waiting Pulls: 0 of maximum 512
```

We can see there is an unprocessed message waiting to be consumed:  

```bash
...> docker exec -it realworldeventsourcing-nats-cli-1 nats consumer next EVENTS TEST_MONITOR
[09:19:23] subj: lfgheroes.events.test_happened / tries: 1 / cons seq: 1 / str seq: 1 / pending: 0
{hello:world}
Acknowledged message

...> docker exec -it realworldeventsourcing-nats-cli-1 nats consumer next EVENTS TEST_MONITOR
nats: error: no message received: nats: timeout
```
