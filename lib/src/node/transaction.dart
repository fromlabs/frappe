import 'dart:async';
import 'dart:collection';

import 'package:frappe/src/node/node.dart';
import 'package:frappe/src/node/node_evaluation.dart';
import 'package:frappe/src/reference.dart';

typedef TransactionHandler = void Function(Transaction transaction);
typedef TransactionRunner<T> = T Function(Transaction transaction);
typedef OnUnreferencedHandler = void Function();
typedef OnUnreferencedInterceptor = void Function(Node, OnUnreferencedHandler);

enum TransactionPhase { opened, evaluation, commit, publish, closing, closed }

class Transaction {
  static const String _transactionZoneParameter = 'transaction';

  static final Set<Node> _globalAlwaysNodes = Set.identity();
  static final Map<Node, TransactionHandler> _globalListenNodes =
      Map.identity();

  static bool get isInTransaction => currentTransaction != null;

  static Transaction get requiredTransaction =>
      currentTransaction ??
      (throw UnsupportedError('Required explicit transaction'));

  static Transaction? get currentTransaction {
    final Transaction? transaction = Zone.current[_transactionZoneParameter];

    return transaction != null && transaction.phase != TransactionPhase.closed
        ? transaction
        : null;
  }

  static void cleanState() {
    _globalListenNodes.clear();
  }

  static void assertCleanState() {
    if (_globalListenNodes.isNotEmpty) {
      print('Listen nodes: $_globalListenNodes');

      throw AssertionError('Not all listen nodes removed');
    }
  }

  static T runRequired<T>(TransactionRunner<T> runner) =>
      runner(requiredTransaction);

  static T run<T>(TransactionRunner<T> runner) {
    if (isInTransaction) {
      return runner(requiredTransaction);
    } else {
      late final Transaction transaction;

      try {
        transaction = Transaction();

        final result = runZoned<T>(() {
          final result = runner(transaction);

          transaction._evaluate();

          transaction._commitValue();

          transaction._publishValue();

          transaction._notifyClosingTransaction();

          return result;
        }, zoneValues: {_transactionZoneParameter: transaction});
        return result;
      } finally {
        transaction._close();
      }
    }
  }

  static void onNodeAdded(Node node) => Transaction.runRequired((transaction) {
        transaction.reference(node);

        if (node.evaluationType == EvaluationType.always) {
          _globalAlwaysNodes.add(node);
        }
      });

  static void onNodeRemoved(Node node) {
    _globalAlwaysNodes.remove(node);
    _globalListenNodes.remove(node);
  }

  static void onUnreferencedInterceptor(
      Node node, OnUnreferencedHandler onUnreferenced) {
    final transaction = Transaction.currentTransaction;

    if (transaction != null && transaction.phase == TransactionPhase.opened) {
      transaction.reference(node);
    } else {
      onUnreferenced();
    }
  }

  static void onEvaluationTypeUpdated(
      Node node, EvaluationType newValue, EvaluationType oldValue) {
    if (oldValue == EvaluationType.always) {
      _globalAlwaysNodes.remove(node);
    }

    if (node.evaluationType == EvaluationType.always) {
      _globalAlwaysNodes.add(node);
    }
  }

  static void addClosingTransactionHandler(
          Node node, TransactionHandler transactionHandler) =>
      _globalListenNodes[node] = transactionHandler;

  static void removeClosingTransactionHandler(Node node) =>
      _globalListenNodes.remove(node);

  final ReferenceGroup _referenceGroup = ReferenceGroup();

  final Map<Node, NodeEvaluation> _evaluations = Map.identity();

  final Set<Node> _pendingNodes = SplayTreeSet<Node>((node1, node2) {
    var delta = node2.evaluationPriority - node1.evaluationPriority;
    return delta != 0 ? delta : node2.id - node1.id;
  });

  TransactionPhase _phase = TransactionPhase.opened;

  TransactionPhase get phase => _phase;

  void reference<R extends Referenceable>(Node node) =>
      _referenceGroup.add(Reference(node));

  // TODO gestione delle eccezioni con handler in transaction
  void onError(Object error, StackTrace stacktrace) =>
      print('Uncaught error: $error\n $stacktrace');

  bool hasValue(Node node) =>
      _phase == TransactionPhase.opened || _phase == TransactionPhase.closing
          ? _evaluations.containsKey(node)
          : throw UnsupportedError(
              'Node value is exposed only in opened/closing transaction phase');

  S getValue<S>(Node<S> node) => hasValue(node)
      ? _evaluations[node]!.value
      : throw StateError('Not evaluated');

  void setValue<S>(Node<S> node, S output) {
    if (_phase != TransactionPhase.opened ||
        _phase == TransactionPhase.closing) {
      throw UnsupportedError(
          'Node value is exposed only in opened/closing transaction phase');
    } else if (!node.isReferenced) {
      throw ArgumentError('Node $node is not referenced');
    }

    _evaluations[node] = NodeEvaluation<S>(output);
  }

  void _close() {
    if (phase == TransactionPhase.closed) {
      throw StateError('Transaction is closed');
    }

    _referenceGroup.dispose();

    _phase = TransactionPhase.closed;
  }

  void _evaluate() {
    _phase = TransactionPhase.evaluation;

    _pendingNodes.addAll(_globalAlwaysNodes);

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
      final inputs = node.createEvaluationInputs(node.sourceReferences.entries
          .map<MapEntry<dynamic, NodeEvaluation?>>((entry) => MapEntry(
              entry.key,
              _evaluations.containsKey(entry.value.value)
                  ? _evaluations[entry.value.value]!
                  : null)));

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
      entry.key.publish(entry.value.value);
    }
  }

  void _notifyClosingTransaction() {
    _phase = TransactionPhase.closing;

    for (final handler in _globalListenNodes.values.toList()) {
      handler(this);
    }
  }
}
