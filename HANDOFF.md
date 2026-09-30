# Microservices Practice Project — Handoff

Continuation notes for picking this up on another machine. Paste this file to Claude at the
start of the new session and say "continue from here".

---

## 1. What this is

A **learning exercise** in event-driven microservices on AWS, using SNS + SQS + Lambda.
First time working with microservices.

**Constraints — these matter, please respect them:**

- **Do not write the code for me.** Guide me, assign me tasks, review what I write.
  I want to learn by doing, not receive a finished repo.
- **It does not need to run.** No `terraform apply`, no AWS account, no deployment.
  The goal is understanding the architecture and the code, not a working system.
- **Keep it light and information-dense.** Concepts + rationale over exhaustive detail.
- Terraform is **not installed** locally, so `terraform fmt` / `validate` / `plan` are
  unavailable. Indentation in `.tf` files is inconsistent as a result — cosmetic, ignore it.

## 2. The teaching format that's working

This pattern has been effective, keep using it:

1. **Explain the concepts first**, with the *why* and the concrete failure mode
   ("get this wrong and you double-charge the customer").
2. **One worked example** of each new resource/pattern, fully written out.
3. **"Your turn"** — I write the remaining N instances myself.
4. **Design questions** at the end of each step to think about, not code.
5. **Review** what I wrote, worst problem first, and explain *why* each mistake matters.

Real failure modes and production gotchas are the most valuable part. Keep including them.

I skip writing answers as code comments — I'll answer design questions in chat instead.

## 3. Architecture

E-commerce order flow. Four services, three SNS topics, four SQS queues (+ 4 DLQs).

```
POST /orders → API Gateway → λ createOrder → DynamoDB Orders (PENDING)
                                           → publish OrderPlaced
                                                  │
                                    ┌─────────────▼──────────────┐
                                    │   SNS: orders-events       │
                                    └──┬──────────┬──────────┬───┘
                                       │          │          │
                                  payment-q  inventory-q  notification-q
                                       │          │          │
                              λ processPayment  λ reserveStock  λ sendNotification
                                       │          │            (console.log only)
                            SNS payments-events  SNS inventory-events
                                       │          │
                                       └────┬─────┘
                                          order-q
                                             │
                                      λ onDomainEvent
                                  (saga: advances order status,
                                   emits OrderConfirmed / OrderCancelled)
```

**Topics count producers; queues count consumers.** They don't match, and shouldn't:

| Service | Publishes | Owns topic | Consumes from queue |
|---|---|---|---|
| order-service | OrderPlaced, OrderConfirmed, OrderCancelled | `orders-events` | `order` |
| payment-service | PaymentCaptured, PaymentFailed | `payments-events` | `payment` |
| inventory-service | InventoryReserved, InventoryRejected | `inventory-events` | `inventory` |
| notification-service | *nothing (leaf)* | *none* | `notification` |

### Routing table (the 6 subscriptions)

| Topic | → Queue | Filter on `eventType` | Status |
|---|---|---|---|
| orders-events | payment | `OrderPlaced`, `OrderCancelled` | ✅ done |
| orders-events | inventory | `OrderPlaced`, `OrderCancelled` | ✅ done |
| orders-events | notification | `OrderPlaced`, `OrderConfirmed`, `OrderCancelled` | ❌ **TODO** |
| payments-events | order | `PaymentCaptured`, `PaymentFailed` | ✅ done |
| payments-events | notification | `PaymentFailed` | ❌ **TODO** |
| inventory-events | order | `InventoryReserved`, `InventoryRejected` | ✅ done |

`order` and `notification` each receive from **two** topics, so their queue policies must
allow both source ARNs (`values` in a `condition` block takes a list).

## 4. Design decisions already made (don't re-litigate)

- **One topic per producing service**, not per event type. Consumers narrow with SNS
  filter policies. Adding an event type then costs zero consumer changes.
- **Exactly one publisher per topic.** Ownership is tagged on each topic resource.
- **SNS → SQS, never the reverse.** SNS copies (1→N, no buffer); SQS buffers (delivered to
  one receiver only, pull-only, cannot push). Each consumer needs its own buffer, so the
  copy must happen first. One queue per consumer — a shared queue would make the three
  services *compete* for messages instead of each seeing every event.
- **Event chaining, not message forwarding.** A service consumes an event, does work, and
  publishes a *new event it owns*. It never re-broadcasts someone else's message.
- **`raw_message_delivery = true`** on every subscription, so `record.body` is our JSON
  directly instead of double-wrapped in an SNS envelope. We lose SNS's metadata, which is
  fine because our own envelope carries `eventId` / `occurredAt` / `source`.
- **Filter on message attributes**, not message body — keeps routing decoupled from
  payload shape. Consequence: **publishers MUST set an `eventType` message attribute** or
  every filtered subscription silently matches nothing.
- **Money as `string`** (e.g. `"10.50"`) + explicit `currency`. Must normalize on write,
  must never `parseFloat` it — use a decimal library if arithmetic is needed. Integer
  minor units (cents) was the other defensible option; float is not.
- **`packages/shared` is types-only and must stay types-only.** It emits zero JavaScript,
  so there is no runtime coupling. The moment runtime code lands there, a bug in it is a
  bug in all four services simultaneously.
- **Per-service DLQ**, not one shared DLQ — because a redrive targets one source queue,
  so "replay everything in here" needs to be a safe single operation.
- **`visibility_timeout_seconds = 180`** = 6 × the planned 30s Lambda timeout, per AWS
  guidance. **`maxReceiveCount = 3`**.
- **Explicit Terraform blocks over `for_each`** for now (see §7 for the optional refactor).

## 5. Current status

### Done — `packages/shared/src/`

- `events.types.ts` — non-exported generic `Envelope<TType, TData>` with `eventId`,
  `eventType`, `occurredAt`, `version`, `source`, `correlationId`, `data`. Seven event
  types, a `DomainEvent` discriminated union, and `EventType = DomainEvent["eventType"]`.
- `payloads.types.ts` — `OrderItem` plus the seven `*Data` payload types.

### Done — `infra/`

- `main.tf` — provider config (aws ~> 5.0, `var.region`).
- `variables.tf` — `region` (us-east-1), `project` (shop), `env` (dev).
- `sns.tf` — all 3 topics, each tagged with its owning service.
- `sqs.tf` — all 4 queue + DLQ pairs, with redrive policies, SSE on every queue
  *including* the DLQs, 14-day DLQ retention vs 4-day main queue retention.
- `subscriptions.tf` — 4 of 6 subscriptions.
- `queue_policies.tf` — 1 of 4 queue policies (payment).

### ❗ Outstanding, in priority order

1. **Bug — `queue_policies.tf` line 24** still reads
   `data.aws_aim_policy_document.payment_queue.json`. The `data` block on line 1 was fixed
   to `aws_iam_policy_document` but the reference to it was not. (This is the third
   mistyped-resource-string bug — see §7.)
2. **Write the 2 missing notification subscriptions** (`orders_to_notification`,
   `payments_to_notification`). Note: notification-service has no topic of its own; a
   subscription is just a wire from an existing topic (`topic_arn`, the source) to an
   existing queue (`endpoint`, the destination).
3. **Write the 3 missing queue policies** — `inventory`, `order`, `notification`. The
   `order` and `notification` ones need two source topic ARNs in the `condition` values list.
4. Then → **Step 3** below.

### Two design questions I have not answered yet

1. The notification subscription lists three event types — why not omit `filter_policy`
   entirely and receive everything from the topic? (Think about what happens when someone
   adds an `OrderRefunded` event, what the `assertNever` exhaustiveness check does with it,
   and where that message ends up.)
2. The `order` queue receives two topics into one queue — what did that cost, versus two
   queues one per topic? (Think about what a poison message from one topic does to the
   other topic's events.)

## 6. Remaining roadmap

| # | Step | What it teaches |
|---|---|---|
| 1 | Event catalog + envelope contract | ✅ done |
| 2a | Terraform: topics, queues, DLQs | ✅ done |
| 2b | Subscriptions, filter policies, queue policies | 🔄 in progress (see §5) |
| 3 | `createOrder` handler — API GW → DynamoDB → SNS | Sync entry point, and the dual-write problem |
| 4 | `processPayment` + `reserveStock` — SQS consumers | Batch handling, idempotency, partial batch failure |
| 5 | `onDomainEvent` — the saga aggregator | State machine over eventual consistency, compensation |
| 6 | Terraform: Lambdas, IAM roles, event source mappings, API Gateway, DynamoDB tables | Least privilege, closing the loop |

**Step 3 is deliberately going to contain a bug.** Write the naive version first:

```ts
await ddb.put(order);              // 1. write the business record
await sns.publish(orderPlaced);    // 2. announce it
```

If step 1 succeeds and step 2 fails, the order exists and nobody will ever be told —
no payment, no reservation, no email, silently, forever. That's the **dual-write problem**.
Write it, feel the hole, *then* discuss the fix: the **transactional outbox**, whose
idiomatic AWS form is DynamoDB Streams (write only to DynamoDB; the stream is part of the
same write, so it can't be missed, and it triggers a Lambda that publishes to SNS).

Also still to be set up when step 3 starts: `package.json` / `tsconfig.json` (deliberately
deferred until the AWS SDK is actually needed), and the `services/*/src/handlers/` tree.

## 7. Recurring mistake to watch for

**Three bugs so far, all the same root cause: typing AWS resource type strings from memory.**

- `sqs_sqs_queue` instead of `aws_sqs_queue`
- `aws_aim_policy_document` instead of `aws_iam_policy_document` (twice — declaration fixed,
  reference still broken)

Two mitigations that already proved useful:

- **Syntax highlighting is a free linter.** An unrecognized resource type loses its
  coloring and stops schema-checking its nested blocks. I noticed this myself once and it
  found a real bug. If a block looks different from the one above it, something is wrong.
- **Use autocomplete, not recall,** inside `resource "` / `data "`. These are API
  identifiers, not English.

Also: naming subscriptions `<topic>_to_<queue>` caught a real bug — the label said
`payments_to_order` while the body pointed at `orders_events`. Keep that convention.

## 8. Concepts already covered (no need to re-teach)

- TypeScript: generic types, string literal types, discriminated unions + narrowing,
  `never` exhaustiveness checks
- Shared code coupling: share the contract, never the code. Tiers of sharing from
  shared-database (fatal) to shared event contract (necessary). Tolerant reader /
  producer-owns-the-schema. Schema registries as the grown-up alternative.
- Terraform: `resource` / `data` / `variable` / `locals` blocks, implicit dependency graph
  via attribute references, `jsonencode`, `aws_iam_policy_document`, `for_each` + `each.key`
- SQS: visibility timeout (and the duplicate-processing timeline when it's too short),
  `maxReceiveCount`, redrive in both directions (automatic to DLQ; manual
  `StartMessageMoveTask` back), SSE-SQS vs SSE-KMS, competing consumers vs fan-out
- SNS: fan-out, filter policies (list = OR, multiple keys = AND, absent key = no match),
  `raw_message_delivery`, message attributes vs message body filter scope
- IAM: identity-based vs resource-based policies, why a cross-service push needs the
  *resource* to opt in, the confused-deputy problem and `aws:SourceArn`
- Silent failure modes: missing queue policy, filter matching nothing, wrong topic ARN —
  all of which apply cleanly, log nothing, and deliver nothing
- At-least-once delivery → idempotency is mandatory; no ordering without FIFO; 256 KB
  message limit → claim-check pattern; sagas and compensating events instead of
  distributed transactions
- EventBridge as the alternative to SNS (content-based routing, schema registry, archive
  and replay, bus-to-bus targeting) and why we chose SNS for learning

## 9. Not yet covered, worth getting to

- CloudWatch alarms on DLQ depth and `ApproximateAgeOfOldestMessage`
- Partial batch failure (`ReportBatchItemFailures`) in the SQS event source mapping
- Idempotency implementation — conditional writes vs a processed-event-ID table with TTL
- Lambda concurrency controls and how a backlog drains
- Structured logging with `correlationId`, and distributed tracing (X-Ray)
- Contract testing between producer and consumer
