# Frappe FRP — Formal Specification

**Version**: 1.0-draft
**Date**: 2026-03-22
**Status**: Living document — canonical reference for correctness, testing, and evolution

This document defines the formal semantics of the Frappe FRP library. All implementation decisions, tests, bug fixes, and new features must be consistent with this specification. Where the implementation deviates from this spec, the spec wins — the implementation must be corrected.

---

## Table of Contents

1. [Foundations](#1-foundations)
2. [Semantic Types](#2-semantic-types)
3. [Operator Semantics](#3-operator-semantics)
4. [Transaction Model](#4-transaction-model)
5. [Algebraic Laws](#5-algebraic-laws)
6. [Constraints and Invariants](#6-constraints-and-invariants)
7. [Resource Management](#7-resource-management)
8. [Scoping Model](#8-scoping-model)
9. [Side Effects and Error Handling](#9-side-effects-and-error-handling)
10. [Glossary](#10-glossary)

---

## 1. Foundations

### 1.1 Design Principle

Frappe follows Conal Elliott's **"semantics first"** discipline: each type and operator has a precise mathematical meaning (denotation). An implementation is correct if and only if it faithfully realizes these denotations.

> Define the meaning of each type and operation first; only then choose an implementation.

### 1.2 Semantic Function

We define a semantic function `mu` that maps each Frappe construct to its mathematical meaning:

```
mu : FrappeExpr -> MathValue
```

For any FRP expression `e`, `mu(e)` is its denotation. Correctness means:

```
forall programs P, forall input sequences I:
  observed_result(P, I) = mu(P)(I)
```

### 1.3 Time Domain

Frappe operates in **discrete logical time**. Time `T` is a monotonically increasing natural number representing a transaction counter:

```
T in N  (natural numbers)
```

There is no continuous time, no wall-clock time, no interpolation between transactions. Two events at the same `T` are **simultaneous** and belong to the same transaction.

---

## 2. Semantic Types

### 2.1 EventStream

An `EventStream<A>` represents a discrete sequence of event occurrences over time:

```
mu(EventStream<A>) = [(T, A)]
```

An ordered list of `(time, value)` pairs with strictly increasing times.

**Invariants:**

- **At-most-once per transaction**: For any stream `s`, all times in `mu(s)` are distinct.

  ```
  forall (t1, _), (t2, _) in mu(s) : t1 != t2
  ```

- **No history**: Streams have no memory. A newly attached listener only receives future events.

- **Finite in any bounded interval**: For any finite time window, only finitely many events occur.

### 2.2 ValueState

A `ValueState<A>` represents a time-varying value that always has a current value:

```
mu(ValueState<A>) = (A_0, [(T, A)])
```

An initial value `A_0` plus an ordered list of updates. The value at any time `t` is:

```
value(vs, t) = last({A_0} union {a | (t', a) in updates(vs), t' <= t})
```

This is a **step function**: the value changes discretely and holds constant between updates.

**Invariants:**

- **Totality**: `getValue()` is a total function — it always returns a value, at any time, in any context.

  ```
  forall t in T : value(vs, t) is defined
  ```

- **Step semantics**: Between updates, the value is constant. There is no interpolation.

### 2.3 Relationship Between EventStream and ValueState

A `ValueState<A>` is internally composed of an initial value and an `EventStream<A>` of updates:

```
ValueState<A> = (LazyValue<A>, EventStream<A>)
```

- `toUpdates()` returns the update stream (without the initial value).
- `toValues()` returns a stream that emits the current value once immediately, then all subsequent updates.
- An EventStream can be converted to a ValueState via `toState(initValue)`.

---

## 3. Operator Semantics

### 3.1 EventStream Operators

#### 3.1.1 map

```
mu(map f s) = [(t, f(a)) | (t, a) in mu(s)]
```

Transforms each event by applying `f`. Does not alter timing.

#### 3.1.2 where

```
mu(where p s) = [(t, a) | (t, a) in mu(s), p(a) = true]
```

Filters events by predicate `p`. Only events satisfying `p` pass through.

#### 3.1.3 distinct

```
mu(distinct eq s) = [(t_i, a_i) | (t_i, a_i) in mu(s),
                      i = 0 or not eq(a_i, a_{i-1})]
```

Suppresses consecutive duplicate events. The first event always passes. Uses `eq` for comparison (defaults to `==`).

#### 3.1.4 once

```
mu(once s) = [head(mu(s))]  if mu(s) is non-empty
           = []              otherwise
```

Emits only the first event, then permanently stops.

#### 3.1.5 merge (binary)

```
mu(merge f s1 s2) = sort(
    [(t, a) | (t, a) in mu(s1), t not in times(mu(s2))]  ++
    [(t, b) | (t, b) in mu(s2), t not in times(mu(s1))]  ++
    [(t, f(a, b)) | (t, a) in mu(s1), (t, b) in mu(s2)]
)
```

Merges two streams. When both fire simultaneously (same `t`), applies the merger function `f` to combine values into a single event. **The at-most-once invariant is preserved.**

Default merger: `f(a, b) = a` (left-biased).

#### 3.1.6 merges (n-ary)

Reduces a list of streams via pairwise `merge`, using a binary-tree structure for balanced priority:

```
mu(merges [s1, ..., sn] f) = fold_tree (merge f) [s1, ..., sn]
```

Left-biased: earlier streams in the list take precedence when merger is not provided.

#### 3.1.7 snapshot

```
mu(snapshot f s vs) = [(t, f(a, value(vs, t-))) | (t, a) in mu(s)]
```

On each event in `s`, samples the **pre-transaction** value of `vs` and combines with the event using `f`.

**Critical timing rule**: `t-` means the value of `vs` at the end of the **previous** transaction, not incorporating any updates from the current transaction. This is what prevents glitches.

**Implementation note**: In the current implementation, `snapshot` reads `vs.getValue()` which returns the committed (post-previous-transaction) value. This is correct because `getValue()` reads `_currentLazyValue`, which is only updated in the commit phase — after evaluation is complete.

#### 3.1.8 accumulate

```
mu(accumulate a_0 acc s) = ValueState with:
  initial = a_0
  updates = [(t_1, acc(e_1, a_0)),
             (t_2, acc(e_2, acc(e_1, a_0))),
             ...]
  where (t_i, e_i) in mu(s)
```

Stateful fold over a stream. Each event is combined with the accumulated state to produce a new state.

**Implementation**: Uses `EventStreamLink` and `ValueStateLink` internally to create a feedback loop within the reactive graph. This is the canonical pattern for cycles — no imperative feedback needed.

#### 3.1.9 collect

```
mu(collect a_0 coll s) = EventStream with:
  [(t_i, out_i) | (t_i, e_i) in mu(s)]
  where (out_i, state_i) = coll(e_i, state_{i-1})
        state_0 = a_0
```

Like `accumulate`, but emits extracted output values instead of the full state. The collector returns a `Tuple2<output, newState>`.

#### 3.1.10 gate

```
mu(gate cond s) = [(t, a) | (t, a) in mu(s), value(cond, t-) = true]
```

Events pass through only when the condition state's **pre-transaction** value is `true`. Uses snapshot semantics internally.

#### 3.1.11 orElse / orElses

```
mu(orElse s1 s2)     = mu(merge (a, b) -> a  s1 s2)
mu(orElses [s1, ...]) = mu(merges [s1, ...] (a, b) -> a)
```

Left-biased merge: when both fire simultaneously, the left stream's value wins.

#### 3.1.12 switchMap

```
mu(switchMap mapper s) = concat(
    [(t, a) | (t, a) in mu(inner_i), t_i <= t < t_{i+1}]
    for each interval [t_i, t_{i+1}) where inner_i = mapper(e_i)
)
where (t_i, e_i) in mu(s)
```

Each event from `s` produces a new inner stream via `mapper`. The output emits events from the **latest** inner stream only. Previous inner streams are unlinked.

**Note**: Events from `s` at time `t_i` switch the inner stream; events from the **new** inner stream at the same time `t_i` are **not** included (the switch takes effect from the next transaction). This is because relinking happens in the closing phase.

### 3.2 ValueState Operators

#### 3.2.1 constant

```
mu(constant v) = (v, [])
```

A ValueState with fixed value `v` and no updates. Immutable.

#### 3.2.2 map

```
mu(map f vs) = (f(a_0), [(t, f(a)) | (t, a) in updates(vs)])
```

Transforms both the initial value and all updates.

#### 3.2.3 combine (binary)

```
mu(combine f vs1 vs2) = (
  f(a_0, b_0),
  [(t, f(value(vs1, t), value(vs2, t))) | t in times(updates(vs1)) union times(updates(vs2))]
)
```

Combines two states pointwise. Re-evaluates whenever **either** input changes. Always reads the current value of both inputs (not just the one that changed).

This is the Applicative `lift` operation.

#### 3.2.4 combines (n-ary)

```
mu(combines [vs1, ..., vsn] f) = (
  f([a_0_1, ..., a_0_n]),
  [(t, f([value(vs1,t), ..., value(vsn,t)]))
   | t in union(times(updates(vs_i)) for all i)]
)
```

Generalizes `combine` to N states. The combiner receives an iterable of all current values.

**Evaluation type**: `almostOneInput` — evaluates when **at least one** input has changed. Non-changed inputs contribute their current committed value.

#### 3.2.5 distinct

```
mu(distinct eq vs) = (a_0, [(t_i, a_i) | (t_i, a_i) in updates(vs),
                             not eq(a_i, prev_i)])
```

Where `prev_0 = a_0` (the initial value). Suppresses updates that equal the previous value. The initial value itself is never suppressed.

#### 3.2.6 switchState

```
mu(switchState vvs) = (
  value(value(vvs, 0), 0),
  -- flattened updates from the currently active inner state
)
```

Unwraps a `ValueState<ValueState<V>>` into a `ValueState<V>`. When the outer state changes to a new inner state, the output:
1. Unlinks from the old inner state
2. Links to the new inner state
3. Emits the new inner state's **current value** via a new transaction

**Relinking happens in the closing phase.** A `Transaction.runNew()` propagates the new inner state's current value.

#### 3.2.7 switchStream

```
mu(switchStream vss) = concat(
    [(t, a) | (t, a) in mu(inner_i), t_i <= t < t_{i+1}]
    for each interval [t_i, t_{i+1}) where inner_i = value(vss, t_i)
)
```

Unwraps a `ValueState<EventStream<E>>` into an `EventStream<E>`. When the outer state changes, relinking happens in the closing phase. **No `runNew` needed** because streams have no current value to propagate.

#### 3.2.8 switchMapState / switchMapStream

```
mu(switchMapState mapper vs) = mu(switchState(map mapper vs))
mu(switchMapStream mapper vs) = mu(switchStream(map mapper vs))
```

Convenience operators: map to inner state/stream, then unwrap.

#### 3.2.9 toValues

```
mu(toValues vs) = [(t_now, value(vs, t_now))] ++ mu(toUpdates vs)
```

Returns a stream that emits the current value **immediately** (in the current or next transaction), then all subsequent updates.

#### 3.2.10 toUpdates

```
mu(toUpdates vs) = updates(vs)
```

Returns just the update stream, without the current value.

---

## 4. Transaction Model

### 4.1 Definition

A **transaction** is the atomic unit of change. It represents a single logical time step `t`.

```
Transaction = {
  time:    T,
  inputs:  Map<SourceNode, Value>,
  phase:   opened | evaluation | commit | publish | closing | closed
}
```

### 4.2 Phase Lifecycle

Every transaction progresses through exactly 6 phases, in order:

```
opened -> evaluation -> commit -> publish -> closing -> closed
```

#### Phase 1: OPENED

- External values are set on source nodes via `setValue(node, value)`.
- Multiple sends to the same node are resolved by the merger function.
- New nodes and links may be created.
- `setValue` is the **only** phase where this operation is allowed.

#### Phase 2: EVALUATION

- Dependent nodes are evaluated in **topological order** (sources before targets).
- Each node's evaluator receives the values of its inputs for this transaction.
- A node evaluates **at most once** per transaction, producing at most one value.
- Evaluation order is determined by `evaluationPriority` (descending).

#### Phase 3: COMMIT

- Evaluated values are committed to each node's persistent state.
- For `ValueState`: `_currentLazyValue` is updated; value references are transferred.
- After commit, `getValue()` returns the new value.
- **This is the boundary**: before commit, `getValue()` returns the previous transaction's value. After commit, it returns this transaction's value.

#### Phase 4: PUBLISH

- Values are delivered to listener callbacks.
- Each listener's `publishHandler` is invoked with the committed value.
- Errors in listeners are caught and reported via `FrappeScope.reportError()`.
- **One listener's error does not prevent other listeners from receiving their values.**
- **Sending values is forbidden** in this phase (throws `UnsupportedError`).

#### Phase 5: CLOSING

- Closing handlers fire. Used by `switchState`, `switchStream`, `switchMap` to relink nodes.
- Handlers may read transaction values via `hasValue()` / `getValue()`.
- Handlers may call `Transaction.runNew()` to propagate values through freshly linked nodes.
- Errors in handlers are caught and reported.
- DAG mutations (unlink/link) happen here, **after** evaluation and publish are complete.

#### Phase 6: CLOSED

- Transaction resources are released (transaction-scoped references disposed).
- No further operations are allowed.

### 4.3 Transaction Nesting

- `Transaction.run()`: Reuses the current transaction if one exists. Creates a new one otherwise.
- `Transaction.runRequired()`: Requires an existing transaction. Throws if none.
- `Transaction.runNew()`: Always creates a new, independent transaction. Used only for internal plumbing (closing handlers). Executes **synchronously inline**: the inner transaction runs its full lifecycle (opened → evaluation → commit → publish → closing → closed) within the outer transaction's closing phase. "Independent" means it has its own evaluation/commit/publish cycle and its own zone — it does not mean deferred or asynchronous.

**Nested `run()` calls coalesce**: inner calls reuse the outer transaction. There is only one evaluation/commit/publish cycle per logical time step.

### 4.4 Evaluation Order

Nodes are evaluated in descending `evaluationPriority` order, which corresponds to **topological order** (sources first, targets last).

Priority is propagated: when a node links to a source, the source's priority increases by the target's priority. This ensures sources always have higher priority than their targets.

**Glitch-freedom theorem**: Under topological evaluation, no node ever sees inconsistent inputs. When a node is evaluated, all its inputs that will fire in this transaction have already been evaluated.

**Proof sketch**: Let node `v` have inputs `{u_1, ..., u_k}`. Since `priority(u_i) > priority(v)` for all `i`, each `u_i` is evaluated before `v` in the priority queue. Therefore `v` sees the final transaction values of all its inputs. QED.

### 4.5 Evaluation Types

Each node has an `EvaluationType` that controls when it participates in evaluation:

| Type | Fires when |
|------|------------|
| `always` | Every transaction (used for initial `toValues` emission) |
| `allInputs` | All inputs have been evaluated and provided values |
| `almostOneInput` | At least one input has been evaluated |
| `never` | Never evaluates (source nodes, disabled `once` nodes) |

---

## 5. Algebraic Laws

These laws **must** hold for any correct implementation. They are derived from the denotational semantics and can be used as test properties.

### 5.1 Functor Laws (EventStream)

```
map id s  ===  s                                    -- identity
map (f . g) s  ===  map f (map g s)                 -- composition
```

### 5.2 Functor Laws (ValueState)

```
map id vs  ===  vs                                  -- identity
map (f . g) vs  ===  map f (map g vs)               -- composition
```

### 5.3 Applicative Laws (ValueState via combine)

Define `pure x = constant x` and `lift2 f a b = combine f a b`. Then:

```
combine (a, b) -> b  (constant x) vs  ===  vs      -- identity
combine f (constant x) (constant y)  ===  constant (f(x, y))  -- homomorphism
```

### 5.4 Merge Laws (EventStream)

For any associative merger function `f`:

```
merge f s (EventStream.never())  ===  s             -- right identity
merge f (EventStream.never()) s  ===  s             -- left identity
merge f (merge f s1 s2) s3  ===  merge f s1 (merge f s2 s3)  -- associativity
```

### 5.5 Filter Laws

```
where (const true) s   ===  s                       -- identity
where p (where q s)    ===  where (x -> p(x) && q(x)) s  -- composition
where p (map f s)      ===  map f (where (x -> p(f(x))) s)  -- filter-map
```

**Note**: The last law only holds when `f` is pure.

### 5.6 Snapshot Laws

```
snapshot (a, v) -> a  s vs  ===  s                  -- ignore sampled value
snapshot (a, v) -> f(a, v)  s (constant c)  ===  map (a -> f(a, c)) s
```

### 5.7 Switch Laws

```
switchState (constant vs)  ===  vs                  -- constant outer = identity
switchStream (constant es) ===  es                  -- constant outer = identity
```

### 5.8 Distinct Laws

```
distinct (distinct s)  ===  distinct s              -- idempotent
```

### 5.9 Once Laws

```
once (once s)  ===  once s                          -- idempotent
map f (once s) ===  once (map f s)                  -- commutes with map
```

---

## 6. Constraints and Invariants

### C1. No Send in Callbacks

**Rule**: Calling `send()` on an `EventStreamSink` or `ValueStateSink` from within a listener callback (publish/closing phase) is **forbidden**.

```
send() is only allowed when:
  Transaction.currentTransaction == null   (outside any transaction)
  OR Transaction.currentTransaction.phase == opened
```

**Rationale** (from Sodium's formal justification):
1. `send()` in a listener bypasses dependency tracking.
2. Without dependency tracking, topological evaluation order is broken.
3. Without topological order, glitch-freedom is broken.
4. Without glitch-freedom, compositionality is broken.
5. Without compositionality, the denotational semantics are unsound.

**Alternative**: Use `EventStreamLink` / `ValueStateLink` for reactive feedback loops. These create cycles **within** the reactive graph, preserving all guarantees.

### C2. At-Most-Once Per Transaction

Each `EventStream` fires at most once per transaction. Multiple `send()` calls to the same sink in one transaction are resolved by the merger function (or throw if no merger is provided).

### C3. DAG Invariant

The node graph is a **directed acyclic graph** at all times. Cycles are detected and rejected at link time.

Forward references (`EventStreamLink`, `ValueStateLink`) allow apparent cycles by deferring the link connection, but the resulting graph must still be a DAG.

### C4. Snapshot Timing

Snapshot always reads the **pre-transaction** value of the sampled `ValueState`. This means updates to the sampled state in the current transaction are **not visible** to the snapshot.

### C5. Atomic Transactions

Transactions are atomic: either all effects are applied or none. No external observer can see intermediate state. Transactions are serialized — there is no interleaving.

### C6. Referential Transparency

Within the reactive graph (phases 1-3: opened, evaluation, commit), the system is referentially transparent. Two expressions with the same denotation are interchangeable:

```
If mu(e1) = mu(e2) then for all contexts C[.], mu(C[e1]) = mu(C[e2])
```

Side effects are confined to the publish phase (phase 4), which is explicitly **outside** the reactive graph.

### C7. ValueState Totality

`getValue()` on a `ValueState` is total — it always returns a value. There is no "uninitialized" state.

### C8. Time-Invariance

The meaning of an FRP expression depends only on the logical order of events, not on absolute time:

```
For any monotone time-remapping phi : T -> T,
if inputs'(t) = inputs(phi(t))
then outputs'(t) = outputs(phi(t))
```

---

## 7. Resource Management

Resource management is **outside** the denotational semantics. The mathematical model assumes infinite lifetimes. The implementation uses reference counting for practical resource management.

### 7.1 Reference Counting

- A `Reference<R>` keeps a `Referenceable` alive.
- A `HostedReference<R>` creates parent->child ownership: the target stays alive only if the host is transitively alive.
- An object is "alive" if at least one non-hosted reference transitively reaches it.
- When all references are disposed, `onUnreferenced()` fires, triggering cleanup.

### 7.2 Liveness Definition

```
alive(obj) = exists ref in references(obj) :
  ref is non-hosted  OR  (ref is hosted AND alive(ref.host))
```

### 7.3 Transaction-Scoped References

During the opened phase, if a node loses all references, the transaction acquires a temporary reference to keep it alive until the transaction closes. This prevents premature disposal during in-flight evaluation.

### 7.4 User-Facing References

- `FrappeReference<F>`: User holds this to keep a stream/state alive. Must be explicitly disposed.
- `FrappeReferenceCollector`: Batch management of multiple references.
- `Finalizer` safety net: If a `FrappeReference` is garbage collected without being disposed, a leak warning is reported.

### 7.5 Correctness Condition

Reference management must be **invisible** to the denotational semantics: as long as a stream/state is alive (has references), its behavior must be identical to the mathematical model. Disposal only affects **future** events — no retroactive changes.

---

## 8. Scoping Model

### 8.1 FrappeScope

A `FrappeScope` provides isolated FRP state. All reactive state (nodes, references, evaluation sets) is scoped — there is no global mutable state.

### 8.2 Zone Propagation

Scopes are propagated via Dart `Zone`s. `scope.run(() { ... })` makes `scope` the current scope for all nested operations. If no explicit scope is active, a global root scope is used.

### 8.3 Isolation Guarantee

Two different scopes are completely isolated. Nodes in scope A cannot link to nodes in scope B. This enables safe parallel testing.

### 8.4 Leak Detection

`scope.assertCleanState()` verifies that no dangling references or unlinked nodes remain. This is the primary tool for detecting resource leaks in tests.

---

## 9. Side Effects and Error Handling

### 9.1 Side Effects

Side effects are confined to the **publish phase** (phase 4). The reactive graph (phases 1-3) is pure.

```
publish : CommittedState -> IO ()
```

Listeners observe the committed state but cannot feed back into the current transaction.

### 9.2 Error Handling in Publish

Errors in listener callbacks are caught and reported via `FrappeScope.reportError()`. They do **not**:
- Abort the transaction
- Prevent other listeners from firing
- Corrupt the reactive graph

### 9.3 Error Handling in Closing

Errors in closing handlers follow the same policy: caught, reported, other handlers still fire.

### 9.4 Error Handling in Evaluation

Errors in user-supplied functions (map, where, accumulate, etc.) during evaluation are **not caught** by the transaction. They propagate to the caller. This is intentional: evaluation errors represent bugs in the reactive graph definition, not runtime conditions.

---

## 10. Glossary

| Term | Definition |
|------|------------|
| **EventStream** | Discrete sequence of events over logical time. Fires at most once per transaction. |
| **ValueState** | Time-varying value with step-function semantics. Always has a current value. |
| **Transaction** | Atomic unit of change. One logical time step. 6 phases. |
| **Node** | Unit of computation in the reactive DAG. Has inputs, evaluator, and outputs. |
| **Glitch** | A node observing inconsistent intermediate state. Prevented by topological evaluation. |
| **Merger** | Function to combine simultaneous events on the same stream. |
| **Sink** | Imperative entry point for pushing values into the reactive graph. |
| **Link** | Forward-declared stream/state for creating cycles within the graph. |
| **Scope** | Isolated container for all FRP state. Propagated via Zones. |
| **Reference** | Ownership handle that keeps a Referenceable alive. |
| **Closing phase** | Post-publish phase where DAG mutations (relinking) occur. |

---

## References

- Conal Elliott, *Push-Pull Functional Reactive Programming*, Haskell Symposium 2009
- Conal Elliott, *Denotational Design with Type Class Morphisms*, 2009
- Stephen Blackheath & Anthony Jones, *Functional Reactive Programming*, Manning 2016
- Sodium denotational specification v1.1 (`Reactive/Sodium/Denotational.hs`)
