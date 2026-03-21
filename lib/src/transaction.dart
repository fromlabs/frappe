import 'dart:async';
import 'dart:collection';

import 'node.dart';
import 'node_evaluation.dart';
import 'reactive_scope.dart';
import 'reference.dart';
import 'typedefs.dart';

typedef TransactionHandler = void Function(Transaction transaction);
typedef TransactionRunner<T> = T Function(Transaction transaction);

/// The current phase of a [Transaction].
enum TransactionPhase { opened, evaluation, commit, publish, closing, closed }

/// Manages atomic evaluation of the reactive computation graph.
///
/// A transaction collects all value changes, evaluates dependent nodes
/// in topological order, commits values, and publishes to listeners.
///
/// Transactions use [ReactiveScope] for all state instead of global variables.
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

  /// Called when a new node is added to the graph.
  static void onNodeAdded(Node node) => Transaction.runRequired((tx) {
        tx.reference(node);
        final scope = ReactiveScope.current;
        if (node.evaluationType == EvaluationType.always) {
          scope.alwaysNodes.add(node);
        }
      });

  /// Called when a node is removed from the graph.
  static void onNodeRemoved(Node node) {
    final scope = ReactiveScope.current;
    scope.alwaysNodes.remove(node);
    scope.listenNodes.remove(node);
  }

  /// Intercepts unreferencing to keep nodes alive during open transactions.
  static void onUnreferencedInterceptor(
      Node node, void Function() onUnreferenced) {
    final transaction = Transaction.currentTransaction;
    if (transaction != null && transaction.phase == TransactionPhase.opened) {
      transaction.reference(node);
    } else {
      onUnreferenced();
    }
  }

  /// Called when a node's evaluation type changes.
  static void onEvaluationTypeUpdated(
      Node node, EvaluationType newValue, EvaluationType oldValue) {
    final scope = ReactiveScope.current;
    if (oldValue == EvaluationType.always) {
      scope.alwaysNodes.remove(node);
    }
    if (newValue == EvaluationType.always) {
      scope.alwaysNodes.add(node);
    }
  }

  /// Registers a handler called during the closing phase.
  static void addClosingTransactionHandler(
      Node node, TransactionHandler handler) {
    ReactiveScope.current.listenNodes[node] = handler;
  }

  /// Removes a closing-phase handler.
  static void removeClosingTransactionHandler(Node node) {
    ReactiveScope.current.listenNodes.remove(node);
  }

  final ReferenceGroup _referenceGroup = ReferenceGroup();
  final Map<Node, NodeEvaluation> _evaluations = Map.identity();
  final Set<Node> _pendingNodes = SplayTreeSet<Node>((node1, node2) {
    var delta = node2.evaluationPriority - node1.evaluationPriority;
    return delta != 0 ? delta : node2.id - node1.id;
  });

  TransactionPhase _phase = TransactionPhase.opened;

  Transaction._();

  TransactionPhase get phase => _phase;

  /// Adds a reference to [node] for the duration of this transaction.
  void reference<R extends Referenceable>(Node node) =>
      _referenceGroup.add(Reference(node));

  /// Handles errors during publish phase.
  void onError(Object error, StackTrace stacktrace) =>
      print('Uncaught error: $error\n $stacktrace');

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
      throw ArgumentError('Node $node is not referenced');
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
    final scope = ReactiveScope.current;

    _pendingNodes.addAll(scope.alwaysNodes);

    for (final sourceNode in List.of(_evaluations.keys)) {
      _evaluateTargetNodes(sourceNode);
    }
    _evaluatePendingNodes();
  }

  void _evaluateTargetNodes(Node sourceNode) {
    for (final targetNode in sourceNode.targetNodes.keys) {
      _evaluateNode(targetNode);
    }
  }

  void _evaluatePendingNodes() {
    while (_pendingNodes.isNotEmpty) {
      final pendingNode = _pendingNodes.first;
      _pendingNodes.remove(pendingNode);
      _evaluateNode(pendingNode, forceEvaluation: true);
    }
  }

  void _evaluateNode(Node node, {bool forceEvaluation = false}) {
    if (!_evaluations.containsKey(node) &&
        node.evaluationType != EvaluationType.never) {
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

      if (forceEvaluation || inputs.allInputsEvaluated) {
        final evaluation = node.evaluate(inputs);
        if (evaluation.isEvaluated) {
          _evaluations[node] = evaluation;
          _pendingNodes.remove(node);
          _evaluateTargetNodes(node);
        }
      } else {
        _pendingNodes.add(node);
      }
    }
  }

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
        onError(e, s);
      }
    }
  }

  void _notifyClosingTransaction() {
    _phase = TransactionPhase.closing;
    final scope = ReactiveScope.current;
    for (final handler in scope.listenNodes.values.toList()) {
      handler(this);
    }
  }
}
