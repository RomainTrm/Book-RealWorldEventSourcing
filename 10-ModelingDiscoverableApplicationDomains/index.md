# 10. Modeling Discoverable Application Domains

> Personal note:  
>> "*[...] this depth needs to be shared and understood by one or more teams collaborating on event-sourced applications. Some events may be shared across teams while others are only used within a single service or piece of the application.*"  
>
> This phrase confirms something I'm thinking since the beginning of the book: for the author, *events* are shared with everyone and also act as contract with other contexts.  
> For me, *events* should remain internal to my context to avoid coupling issues and preserve the team's ability to change them. Furthermore, the granularity may not be adapted for other applications. For communication outside our context (and with other applications), we should send dedicated messages with *notifiers*.  

This chapter is about tools and techniques that can help manage the application and keep documentation sync with the code. In the first part, we'll see how to document individual events and commands. In the second part, we'll see a higher level of modeling and document flows.  

## Defining and Documenting Schemas

We can document code structure to define expected types:  

```elixir
defmodule LunarFrontiers.App.Events.BuildingSpawned.V2 do
  @type t :: %__MODULE__ {
    site_id: String.t,
    game_id: String.t,
    site_type:  :oxygen_generator |
                :water_generator  |
                :hq               |
                :power_generator  |
                :colonist_housing,
    location: Point.t,
    player_id: String.t,
    tick: integer,
    completion_ticks: integer
  }

  @enforce_keys [:site_id, :game_id, :site_type]

  @derive Jason.Encoder
  defstruct [:site_id, :game_id, :site_type, :location, :player_id,
             :tick, :completion_ticks]
end
```

This is a move in the right direction as we can see quickly what type of values to expect. Though this doesn't solve our discoverability and documentation problem for other stakeholders. Our next move is to look at various Domain Specific Languages (DSLs) for schema definition.

### Modeling with JSON Schemas

[JSON Schema](https://json-schema.org/) is a declarative language that annotates and validates JSON documents. It is human readable and is processed by any language that can read JSON. It's also ubiquitous, all the major languages have libraries for parsing JSON schemas and validating documents against those.  

```json
{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://lunarfrontiers.com/schema/events/building_spawned.json",
    "title": "BuildingSpawned",
    "description": "An event indicating a building spawned",
    "type": "object",
    "properties": {
        "site_id": {
            "description": "A UUID for the site",
            "type": "string"
        },
        "site_type": {
            "description": "The type of this building",
            "type": "string",
            "enum": ["HQ", "OxygenGenerator", "WaterGenerator", "Housing"]
        },
        ...
    }
}
```

### Modeling with Protocol Buffers

[Protocol buffers](https://protobuf.dev/) are a language and platform-neutral way of describing and serializing data with some means of describing schema via a Schema Definition Language (SDL).  

```proto
syntax = "proto3";

enum SiteType {
  HQ = 0;
  OXYGEN_GENERATOR = 1;
  WATER_GENERATOR = 2;
  POWER_GENERATOR = 3;
}

message Point {
  uint32 x = 1;
  uint32 y = 2;
}

message BuildingSpawned {
  string site_id = 1;
  string game_id = 2;
  SiteType site_type = 3;
  Point location = 4;
  string player_id = 5;
  uint64 ticks = 6;
  uint32 completion_ticks = 7;
}
```

To work with protobufs, we have to install a suitable `protoc` application for our CPU and OS. Then we can use the CLI to generate code. For example, to generate C# code: `protoc buildingspawned.ptroto --csharp_out=`

Here's a fragment of the generated code:  

```csharp
public enum SiteType {
  [pbr::OriginalName("HQ")] Hq = 0,
  [pbr::OriginalName("OXYGEN_GENERATOR")] OxygenGenerator = 1,
  [pbr::OriginalName("WATER_GENERATOR")] WaterGenerator = 2,
  [pbr::OriginalName("POWER_GENERATOR")] PowerGenerator = 3,
}
```

### Modeling with Avro

[Apache Avro](https://avro.apache.org/) is a data serialization system. This works well with Kafka. There are several ways to represent a schema (like JSON), but Avro provide it's own Interface Definition Language (IDL):  

```avro
enum SiteTypes {
    OXYGENERATOR, WATERGENERATOR, POWERGENERATOR, HQ, HOUSING
}
record BuildingSpawned {
    string site_id;
    string game_id;
    SiteTypes site_type;
    Point location;
    string player_id;
    int ticks;
    int completion_ticks;
}
```

Contrary to protobufs, Avro doesn't require any code generation.

### Examining Cloud Events

*Cloud Events* codify the *envelope* pattern that is used by many applications. Though, it doesn't provide any mechanism to externally document the schema.  
*Cloud Events* can be represented in JSON, but also with [Avro](https://github.com/cloudevents/spec/blob/main/cloudevents/formats/avro-format.md) or [Protocol Buffers](https://github.com/cloudevents/spec/blob/main/cloudevents/formats/protobuf-format.md).

### Deciding on an Event Schema Language

Choosing a technology depends on existing technologies in the company, the choices made to model the flow and the preferences of the team.

## Modeling Event Flows

Schema definition is not sufficient as they do not provide any information about data flows. Any complex event-sourced application comes with an intrinsic lack of visibility into how commands and events flow through the system. This is especially true for *process managers*.

### Event Flows are Directed Graphs

To describe our system, we usually say things like "xxx emits the event yyy" or "xxx consumes the event yyy". Verbs like *emits* or *consumes* are hints that the flow follows a direction.

```goat
Withdraw funds                  > Funds Withdrawn
               \               /
                > Bank Account
               /               \
Deposit funds                   > Funds Deposited
```

This example is simple, but these schemas can increase in complexity so fast that there really hard to maintain by hand.

> Personal note: The following tools look great, but none of them seems to be able to document a flow from an existing code base.

### Specifying Systems with AsyncAPI

[AsyncAPI](http://asyncapi.com/) is a set of tools for defining asynchronous APIs. This is a general-purpose specification tool so its terminology isn't perfectly fitted with event-sourcing terminology.  

An AsyncApi document is made up of:  

- *Server*: a broker system responsible for connecting *consumers* and *producers*.
- *Producer*: an "application" that published messages.
- *Consumer*: an "application" that listens for events.
- *Channel*: the *means* (topics, queues, routes, ...) by with messages flow through servers.  
- *Application*: a broad category that can be a program or collection of programs.
- *Protocol*: defines *how* information flows through the system.
- *Message*: a unit of data transmitted from a *producer* to a *consumer* through a *sever*.

We can describe each element of our system with a specification file, then AsyncApi combines them all into a single specification that can be fed into tools and code generators.  

### Specifying Systems with Event Catalog

Keeping diagrams and code sync is a burden when not automated. [Event Catalog](https://www.eventcatalog.dev/) tries to solve this issue. It's a tool that produces static websites with graph visualization, interactive and filterable node visualizers of applications and subdomains as well as a way to store and visualize JSON schemas.  

It can ingest data from other sources, including AsyncAPI. It can also be used as a code generation source.  

### Specifying Systems with RDF

By storing our flow into a graph database, we can get visualization. We can also attach a code generator to keep code in sync with the documentation.  
There are other ways to represent a graph outside of native databases. For example [RDF](https://www.w3.org/TR/rdf11-concepts/) (Resource Description Framework) let us compose triples from a *subject*, a *predicate* and an *object*.  
[Turtle](https://www.w3.org/TR/rdf12-turtle/) is a more human-friendly and tool-friendly way of representing a graph. These graphs definition can be visualized with tools like [graphviz](https://graphviz.org/).

## Modeling Case Study: Crafter Hustle

The application modeled is called Craft Hustle and is designed to make life easier for people making and selling crafts through multiple channels.

### Collecting the Jobs to Be Done

Here are the high-level items:  

- Keep track of supplies needed to make pieces of art.
- Keep track of the art they have on hand.
- Get useful information about going to craft shows to sell their wares. Specifically, was the profit worth the cost of being a vendor? They want to use that to figure out which shows to do next year.
- Manage consignments to different stores for different periods of time.
- Track sales of art via online and direct sales.

These are the expert's words describing what the expert needs to do, no technical jargon here.  

### Establish a Common Language

Then we define terms to make sure we understand each other. For example:  

*Inventory* refers to "stuff" a crafter has made that's in their possession (it doesn't matter where). These are finished products and not supplies used to make things. Each piece of inventory is considered unique, even if they've made a dozen of them.  

In this case study, the author also defines *supplies*, *show*, *consignment merchant*, *consignment period* and *custom order*.  

### Discover Flows from the User's Perspective

A flow describes the sequence of "events" as seen through the eyes of the user. The author suggests starting with the most complex flow first, as discoveries can make the remaining ones easier.  
Here's one flow:  

1. Make products (consume supplies)
2. Deliver products to consignment merchants (consignment period begins)
3. Merchant makes multiple sales of products; crafter may not know the details until the end of the period
4. Consignment period ends (merchant is out of inventory or time elapses)
5. Sales details are delivered to crafter
6. Any remaining product is returned to crafter

This is still a high-level flow, at least another translation needs to be done to obtain a set of events and aggregates.  

```goat
+-------------------+     +----------------------------+     +-------------------------------+     +-------------------------+
| Agreement Reached +---->+ Consignment Period Started +--+->+   Consignment Period Ended    +--+->+    Inventory Returned   |
+-------------------+     +-------------+--------------+  |  +-------------------------------+  |  +-------------------------+
                                        ^                 |                                     |
                          +-------------+--------------+  |  +-------------------------------+  |  +-------------------------+
                          |     Inventory Delivered    |  +->+   Consignment Product Sold    |  +->+ Order History Delivered |
                          +-------------+--------------+     +---------------+---------------+  |  +-------------------------+
                                        ^                                    v                  |
+-------------------+     +-------------+--------------+     +---------------+---------------+  |  +-------------------------+
| Supplies Consumed +---->+      Product Created       |     | Consignment Inventory Reduced |  +->+ Funds Given to Crafter  |
+-------------------+     +----------------------------+     +-------------------------------+     +-------------------------+
```

This diagram still isn't something that resembles an event-sourcing design.

### Iterate on the Model Document

Iterating on the model document can be difficult. Avoid involving non-technical people as functional and technical concerns are different viewpoints. 

### Build the App

An event model is never finished, it's simply rich enough to start coding.
