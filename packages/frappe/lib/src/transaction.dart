import 'dart:async';

import 'node.dart';
import 'node_evaluation.dart';
import 'frappe_scope.dart';
import 'reference.dart';

/// Callback invoked during a specific transaction phase.
typedef TransactionHandler = void Function(Transaction transaction);

/// Function that executes logic within a [Transaction] and returns a result.
typedef TransactionRunner<T> = T Function(Transaction transaction);

/// The current phase of a [Transaction].
enum TransactionPhase { opened, evaluation, commit, publish, closing, closed }

/// Manages atomic evaluation of the reactive computation graph.
///
/// A transaction collects all value changes, evaluates dependent nodes
/// in topological order, commits values, and publishes to listeners.
///
/// Transactions use [FrappeScope] for all state instead of global variables.
class Transaction {
  static const String _transactionZoneParameter = 'transaction';

  /// Whether a transaction is currently active.
  static bool get isInTransaction => currentTransaction != null;

  /// Gets the current transaction, throwing if none exists.
  static Transaction get requiredTransaction =>
      currentTransaction ??
      (throw UnsupportedError('Required explicit transaction'));

  /// Gets the current transaction from the zone, or null.
  static Transaction? get currentTransaction {
    final Transaction? transaction = Zone.current[_transactionZoneParameter];
    return transaction != null && transaction.phase != TransactionPhase.closed
        ? transaction
        : null;
  }

  /// Runs [runner] within the required current transaction.
  static T runRequired<T>(TransactionRunner<T> runner) =>
      runner(requiredTransaction);

  /// Runs [runner] within a transaction, creating one if needed.
  ///
  /// If already in a transaction, reuses it. Otherwise creates a new
  /// transaction that goes through: opened → evaluation → commit →
  /// publish → closing → closed.
  static T run<T>(TransactionRunner<T> runner) {
    if (isInTransaction) {
      return runner(requiredTransaction);
    }

    late final Transaction transaction;
    try {
      transaction = Transaction._();
      final result = runZoned<T>(
        () {
          final result = runner(transaction);
          transaction._evaluate();
          transaction._flushDeferredPriorityUpdates();
          transaction._commitValue();
          transaction._publishValue();
          transaction._notifyClosingTransaction();
          return result;
        },
        zoneValues: {_transactionZoneParameter: transaction},
      );
      return result;
    } finally {
      transaction._close();
    }
  }

  /// Always creates a new transaction, ignoring any current one.
  ///
  /// Used by closing handlers (e.g., switchState) to propagate values
  /// after relinking nodes.
  static T runNew<T>(TransactionRunner<T> runner) {
    late final Transaction transaction;
    try {
      transaction = Transaction._();
      final result = runZoned<T>(
        () {
          final result = runner(transaction);
          transaction._evaluate();
          transaction._flushDeferredPriorityUpdates();
          transaction._commitValue();
          transaction._publishValue();
          transaction._notifyClosingTransaction();
          return result;
        },
        zoneValues: {_transactionZoneParameter: transaction},
      );
      return result;
    } finally {
      transaction._close();
    }
  }

  /// Registers a newly created node within the current transaction.
  ///
  /// Acquires a transaction-scoped reference to keep the node alive and,
  /// if the node has [EvaluationType.always], adds it to the scope's
  /// always-evaluate set so it participates in every transaction.
  static void onNodeAdded(Node node) => Transaction.runRequired((tx) {
        tx.reference(node);
        final scope = FrappeScope.current;
        if (node.evaluationType == EvaluationType.always) {
          scope.alwaysNodes.add(node);
        }
      });

  /// Unregisters a node from the scope's tracking sets.
  ///
  /// Removes the node from both the always-evaluate set and the
  /// closing-phase listener map, ensuring it no longer participates
  /// in future transactions.
  static void onNodeRemoved(Node node) {
    final scope = FrappeScope.current;
    scope.alwaysNodes.remove(node);
    scope.listenNodes.remove(node);
  }

  /// Intercepts unreferencing to keep nodes alive during open transactions.
  ///
  /// When a node loses all its external references during the opened phase,
  /// it must stay alive until the transaction completes so that in-flight
  /// evaluations can still read its value. A transaction-scoped reference
  /// is acquired instead of calling [onUnreferenced] immediately.
  static void onUnreferencedInterceptor(
      Node node, void Function() onUnreferenced) {
    final transaction = Transaction.currentTransaction;
    // During the opened phase, defer cleanup by holding a tx-scoped reference;
    // otherwise, proceed with immediate unreferencing.
    if (transaction != null && transaction.phase == TransactionPhase.opened) {
      transaction.reference(node);
    } else {
      onUnreferenced();
    }
  }

  /// Updates the scope's always-evaluate set when a node's evaluation type changes.
  ///
  /// Ensures the node is present in or absent from the always-evaluate set
  /// according to its new [EvaluationType].
  static void onEvaluationTypeUpdated(
      Node node, EvaluationType newValue, EvaluationType oldValue) {
    final scope = FrappeScope.current;
    if (oldValue == EvaluationType.always) {
      scope.alwaysNodes.remove(node);
    }
    if (newValue == EvaluationType.always) {
      scope.alwaysNodes.add(node);
    }
  }

  /// Registers a handler to be invoked during the closing phase of every transaction.
  ///
  /// Used by operators like `switchState` and `switchStream` to relink nodes
  /// after the main evaluation/publish cycle completes.
  static void addClosingTransactionHandler(
      Node node, TransactionHandler handler) {
    FrappeScope.current.listenNodes[node] = handler;
  }

  /// Removes a previously registered closing-phase handler for [node].
  static void removeClosingTransactionHandler(Node node) {
    FrappeScope.current.listenNodes.remove(node);
  }

  final ReferenceGroup _referenceGroup = ReferenceGroup();
  final Map<Node, NodeEvaluation> _evaluations = Map.identity();
  // Nodes waiting to be evaluated. Uses a List instead of SplayTreeSet
  // because priority updates are deferred during evaluation (see
  // _deferOrRunPriorityUpdate), so a self-balancing tree would not see
  // the mutations anyway. Sorted once before draining in
  // _evaluatePendingNodes.
  final List<Node> _pendingNodes = [];
  // Priority updates deferred from the evaluation phase. When mappers
  // create FRP objects during evaluation, _propagatePriority is queued
  // here instead of executing immediately, to avoid mutating priorities
  // while the pending list is being drained. Flushed after evaluation.
  final List<void Function()> _deferredPriorityUpdates = [];

  TransactionPhase _phase = TransactionPhase.opened;

  Transaction._();

  /// The current phase of this transaction.
  TransactionPhase get phase => _phase;

  /// Acquires a reference to [node] scoped to this transaction's lifetime.
  ///
  /// The reference is released when the transaction closes, preventing
  /// premature disposal of nodes involved in the current evaluation cycle.
  void reference<R extends Referenceable>(Node node) =>
      _referenceGroup.add(Reference(node));

  /// Queues a priority update for execution after evaluation completes.
  ///
  /// Called by [Node._linkTarget] / [Node._unlinkTarget] when linking
  /// happens during the evaluation phase (e.g., mapper functions creating
  /// FRP objects). Deferring prevents mutation of [_pendingNodes] ordering.
  void deferPriorityUpdate(void Function() update) =>
      _deferredPriorityUpdates.add(update);

  /// Reports a boundary error via the current scope's error handler.
  ///
  /// If the error handler itself throws, falls back to the zone's uncaught
  /// error handler to surface the problem without aborting the delivery loop.
  static void _reportError(Object error, StackTrace stackTrace) {
    try {
      FrappeScope.current.reportError(error, stackTrace);
    } catch (handlerError, handlerStack) {
      Zone.current.handleUncaughtError(handlerError, handlerStack);
    }
  }

  /// Whether [node] has a value in this transaction.
  bool hasValue(Node node) =>
      _phase == TransactionPhase.opened || _phase == TransactionPhase.closing
          ? _evaluations.containsKey(node)
          : throw UnsupportedError(
              'Node value is accessible only in opened/closing phase');

  /// Gets the value of [node] in this transaction.
  S getValue<S>(Node<S> node) => hasValue(node)
      ? _evaluations[node]!.value
      : throw StateError('Node $node not evaluated in this transaction');

  /// Sets the value of [node] in this transaction.
  void setValue<S>(Node<S> node, S output) {
    if (_phase != TransactionPhase.opened) {
      throw UnsupportedError(
          'Node value can only be set in opened transaction phase');
    }
    if (!node.isReferenced) {
      throw ArgumentError('Node ${node.debugLabel} is not referenced');
    }
    _evaluations[node] = NodeEvaluation<S>(output);
  }

  void _close() {
    if (phase == TransactionPhase.closed) {
      throw StateError('Transaction is already closed');
    }
    _referenceGroup.dispose();
    _phase = TransactionPhase.closed;
  }

  void _evaluate() {
    _phase = TransactionPhase.evaluation;
    final scope = FrappeScope.current;

    // Step 1: Seed pending set with always-evaluate nodes (e.g., listeners)
    // so they are visited even if no source explicitly feeds them.
    _pendingNodes.addAll(scope.alwaysNodes);

    // Step 2: Walk downstream from every source node that received a value
    // during the opened phase, eagerly evaluating reachable targets.
    for (final sourceNode in List.of(_evaluations.keys)) {
      _evaluateTargetNodes(sourceNode);
    }

    // Step 3: Drain remaining pending nodes (always-evaluate and deferred
    // nodes whose inputs weren't all available during the eager walk).
    _evaluatePendingNodes();
  }

  /// Executes priority updates that were deferred during evaluation.
  ///
  /// Runs between evaluation and commit so that priorities are correct
  /// for the next transaction without disturbing the current one.
  void _flushDeferredPriorityUpdates() {
    for (final update in _deferredPriorityUpdates) {
      update();
    }
    _deferredPriorityUpdates.clear();
  }

  void _evaluateTargetNodes(Node sourceNode) {
    for (final targetNode in sourceNode.targetNodes.keys) {
      _evaluateNode(targetNode);
    }
  }

  // Ascending comparator: highest evaluationPriority ends up last so that
  // removeLast() extracts the node that should be evaluated first (closest
  // to sources). Tiebreaker: highest ID last (matches prior SplayTreeSet
  // behaviour where higher IDs were evaluated first at equal priority).
  static int _priorityComparator(Node a, Node b) {
    final delta = a.evaluationPriority.compareTo(b.evaluationPriority);
    return delta != 0 ? delta : a.id.compareTo(b.id);
  }

  void _evaluatePendingNodes() {
    // Priorities are stable during evaluation (updates are deferred), so a
    // single sort is sufficient to establish correct topological order.
    _pendingNodes.sort(_priorityComparator);
    while (_pendingNodes.isNotEmpty) {
      final pendingNode = _pendingNodes.removeLast();
      _evaluateNode(pendingNode, forceEvaluation: true);
    }
  }

  void _evaluateNode(Node node, {bool forceEvaluation = false}) {
    // Skip nodes that were already evaluated or are marked as never-evaluate.
    if (!_evaluations.containsKey(node) &&
        node.evaluationType != EvaluationType.never) {
      // Build the inputs snapshot: for each source, include its evaluation
      // result from this transaction (or null if the source wasn't evaluated).
      final inputs = node.createEvaluationInputs(
        node.sourceReferences.entries.map<MapEntry<dynamic, NodeEvaluation?>>(
          (entry) => MapEntry(
            entry.key,
            _evaluations.containsKey(entry.value.value)
                ? _evaluations[entry.value.value]!
                : null,
          ),
        ),
      );

      // Evaluate immediately when forced (pending-drain phase) or when all
      // upstream inputs have been evaluated (eager walk). Otherwise, defer
      // the node into the pending set for later processing.
      if (forceEvaluation || inputs.allInputsEvaluated) {
        final evaluation = node.evaluate(inputs);
        if (evaluation.isEvaluated) {
          _evaluations[node] = evaluation;
          _pendingNodes.remove(node);
          _evaluateTargetNodes(node);
        }
      } else if (!_pendingNodes.contains(node)) {
        _pendingNodes.add(node);
      }
    }
  }

  // --- Error handling strategy across transaction phases ---
  //
  // Evaluation and commit are *internal* phases: they execute framework code
  // (node evaluateHandlers and commitHandlers) that is expected to be infallible.
  // An exception here indicates a bug in the framework or a violated invariant,
  // so we let it propagate — aborting the transaction before any listener is
  // notified. The finally block in run()/runNew() still calls _close() to
  // release transaction-scoped references.
  //
  // Publish and closing are *external* phases: they invoke user-supplied
  // listeners and closing handlers (e.g., switchState relinking) that may
  // legitimately throw. Each iteration is individually try-caught so that one
  // failing handler does not prevent delivery to the remaining handlers.
  //
  // Note on commit atomicity: if a commitHandler were to throw mid-loop, nodes
  // committed before the failure would keep their new values while the rest
  // would retain old values — a partial commit. True rollback would require
  // snapshotting pre-commit state, adding significant complexity. In practice
  // commitHandlers only perform assignments and reference bookkeeping (see
  // ValueState._node.commitHandler), so failures are not expected.

  void _commitValue() {
    _phase = TransactionPhase.commit;
    for (final entry in _evaluations.entries) {
      entry.key.commit(entry.value.value);
    }
  }

  void _publishValue() {
    _phase = TransactionPhase.publish;
    for (final entry in _evaluations.entries) {
      try {
        entry.key.publish(entry.value.value);
      } catch (e, s) {
        _reportError(e, s);
      }
    }
  }

  void _notifyClosingTransaction() {
    _phase = TransactionPhase.closing;
    final scope = FrappeScope.current;
    for (final handler in scope.listenNodes.values.toList()) {
      try {
        handler(this);
      } catch (e, s) {
        _reportError(e, s);
      }
    }
  }
}
