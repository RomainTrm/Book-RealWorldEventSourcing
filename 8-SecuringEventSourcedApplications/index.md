# 8. Securing Event-Sourced Applications

Security in event-sourced applications can be divided into zones:  

- Aggregates and incoming command requests
- The event stream
- Sensitive information on events
- Projections
- Process manager state

## Securing Event Streams

First of all, we have to determine which parts of the application need their own isolated security and which one can rely on a broader umbrella.  

As a corrupted event stream leads to unintended application behaviors, and as it can be manipulated by attackers, it deserves to be secured independently of the rest of the application. So we want to make sure that anyone writing new events in the stream is allowed to do so. For example, NAT's message broker comes with a technology called [JetStream](https://docs.nats.io/nats-concepts/jetstream) that ask to every writing attempt a valid JWT. This has the double benefit of securing the event log and add some audit trail that correlates events to users.  

We also want to make sure event log is only accessible by our system and no one else.  

As JWT (or other custom token) can be added to the payload for audits, like for the rest of the event, we have to choose a solution that will last over time.  

In cloud events, they can also be used as the source:  

```json
{
    "specversion": "1.0",
    "id": "<some-id>",
    "type": "building_spawned",
    "source": "efhFDofdfhioFDDFfspio....so",
    "datacontenttype": "application/json",
    ...
}
```

## Securing Command Paths

Commands are regular *request/reply*, we can see them as regular requests to our service. Before sending a command to an *aggregate*, we have to ensure *authentication* (who is it?) and *authorization* (what can it do?). Then it is *aggregate*'s responsibility to validate business rules.  

## Securing Projection and Component States

This is relatively straightforward: we have to ensure only authorized components can read and write various data stores. In a perfect world, each one of them will have their own unique authentication.  

## Supporting GDPR and the Right to Be Forgotten

*GDPR* (*General Data Protection Regulation*) has a huge influence on how backends, storage plans and architectures are designed. Here we focus on the "right of erasure".  

### Crypto-Shredding

*Crypto-shredding* is a technique that can be used to effectively dispose of PII (*Personally Identifiable Information*) without violating *"events are immutable"* law. In this context, shredding refers to disposing/forgetting a private key required to decrypt sensitive information.  

In such case, PII information is encrypted in the event payload and the encryption key's id is added to the metadata while keys remains stored in a dedicate vault (like [HashiCorp Vault](https://developer.hashicorp.com/vault)):  

```json
{
    "specversion": "1.0",
    "id": "<some-id>",
    "type": "fund_withdrawn",
    "source": "efhFDofdfhioFDDFfspio....so",
    "datacontenttype": "application/json",
    "x-pii-reference-key": "<encryption-key-id>",
    "data": {
        "account_number": "<encrypted-value>",
        "amount": 2300,
        ...
    }
    ...
}
```

### Supporting Retention Periods

Sometimes we may want to forget expired data. This can also be achieved with *crypto-shredding*.  
To do so, we encrypt our data a first time with our PII encryption key, then a second type with an expiring "retention period" key. When the retention time is exceeded, then we dispose our retention key. If the information is *renewed*, then we decrypt the outer layer and re-encrypt it with a new retention period key.  

```goat
+---------------------------------------------------+
| Outer event (Cloud event)                         |
|                                                   |
| +---------------------------+   +---------------+ |
| | Account Number            |   | Amount        | |
| | +-------------------------+   +---------------+ |
| | | Retention encrypt       |                     |
| | | +-----------------------+   +---------------+ |
| | | | PII Reference encrypt |   | Clearing Date | |
| +-+-+-----------------------+   +---------------+ |
+---------------------------------------------------+
```

### Rationalizing Crypto-Shredding with External Context

We can see crypto-shredding as a violation of the laws saying that our system cannot depend on information outside of our events. Logically, a clear and an encrypted value are the same, just not stored in the same form so this is not a violation.  

> Personal note: by disposing a key, we're just unable to read a PII value. As long as we're not applying any logic to it, having "John Doe" or "fjdiFDDOjfdFd" is the same. We could argue that it can be an issue if an encrypted value is needed to perform a task, but this is probably the sign that some logic isn't sitting at the right place.  
