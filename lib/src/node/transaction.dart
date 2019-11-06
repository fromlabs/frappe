import 'dart:async';
import 'dart:collection';

import '../reference.dart';
import '../node.dart';
import 'node_evaluation.dart';

typedef TransactionHandler = void Function(Transaction transaction);
typedef TransactionRunner<T> = T Function(Transaction transaction);

enum TransactionPhase { OPENED, EVALUATION, COMMIT, PUBLISH, CLOSING, CLOSED }

void cleanAllListenNodes() {
  Transaction._globalListenNodes.clear();
}

void assertAllListenNodes() {
  if (Transaction._globalListenNodes.isNotEmpty) {
    print('Listen nodes: ${Transaction._globalListenNodes}');

    throw AssertionError('Not all listen nodes removed');
  }
}

class Transaction {
  static const String _transactionZoneParameter = 'transaction';

  static final Map<Node, TransactionHandler> _globalListenNodes =
      Map.identity();

  static bool _isInitialized = false;

  static bool get isInTransaction => currentTransaction != null;

  static Transaction get requiredTransaction => currentTransaction != null
      ? currentTransaction
      : throw UnsupportedError('Required explicit transaction');

  static Transaction get currentTransaction {
    final Transaction transaction = Zone.current[_transactionZoneParameter];

    return transaction != null && transaction.phase != TransactionPhase.CLOSED
        ? transaction
        : null;
  }

  static init() {
    _isInitialized = true;
    nodeGraph.addNodeHandler = Transaction.addNode;
    nodeGraph.removeNodeHandler = Transaction.removeNode;
  }

  static T runRequired<T>(TransactionRunner<T> runner) =>
      runner(requiredTransaction);

  static T run<T>(TransactionRunner<T> runner) {
    if (isInTransaction) {
      return runner(currentTransaction);
    } else {
      Transaction transaction;

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
        transaction?._close();
      }
    }
  }

  static void addNode(Node node) => Transaction.runRequired((transaction) {
        final reference = Reference(node);

        if (reference.value.evaluationType == EvaluationType.FIRST_EVALUATION) {
          transaction._firstNodes.add(reference.value);
        }

        transaction._referenceGroup.add(reference);
      });

  static void removeNode(Node node) {
    _globalListenNodes.remove(node);
  }

  final ReferenceGroup _referenceGroup = ReferenceGroup();

  final Map<Node, NodeEvaluation> _evaluations = Map.identity();

  final Set<Node> _firstNodes = Set.identity();

  final Set<Node> _pendingNodes = SplayTreeSet<Node>(
      (node1, node2) => node2.evaluationPriority - node1.evaluationPriority);

  TransactionPhase _phase = TransactionPhase.OPENED;

  Transaction() {
    if (!_isInitialized) {
      throw StateError('Transaction not initialized');
    }
  }

  TransactionPhase get phase => _phase;

  N node<N extends Node>(N node) {
    _referenceGroup.add(Reference(node));

    return node;
  }

  void addClosingTransactionHandler(
          Node node, TransactionHandler transactionHandler) =>
      _globalListenNodes[node] = transactionHandler;

  // TODO gestione delle eccezioni con handler in transaction
  void onError(Object error, StackTrace stacktrace) =>
      print('Uncaught error: $error\n $stacktrace');

  bool hasValue(Node node) =>
      _phase == TransactionPhase.OPENED || _phase == TransactionPhase.CLOSING
          ? _evaluations.containsKey(node)
          : throw UnsupportedError(
              'Node value is exposed only in opened/closing transaction phase');

  S getValue<S>(Node<S> node) => hasValue(node)
      ? _evaluations[node].value
      : throw StateError('Not evaluated');

  void setValue<S>(Node<S> node, S output) {
    if (_phase != TransactionPhase.OPENED ||
        _phase == TransactionPhase.CLOSING) {
      throw UnsupportedError(
          'Node value is exposed only in opened/closing transaction phase');
    } else if (!node.isReferenced) {
      throw ArgumentError('Node $node is not referenced');
    }

    _evaluations[node] = NodeEvaluation<S>(output);
  }

  void _close() {
    if (phase == TransactionPhase.CLOSED) {
      throw StateError('Transaction is closed');
    }

    _referenceGroup.dispose();

    _phase = TransactionPhase.CLOSED;
  }

  void _evaluate() {
    _phase = TransactionPhase.EVALUATION;

    _pendingNodes.addAll(_firstNodes);

    for (final sourceNode in List.of(_evaluations.keys)) {
      _evaluateTargetNodes(sourceNode);
    }

    _evaluatePendingNodes();
  }

  void _evaluateTargetNodes(Node sourceNode) {
    for (final targetNode in nodeGraph.getTargetNodes(sourceNode).keys) {
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
    if (!_evaluations.containsKey(node)) {
      bool allInputsEvaluated = true;
      final inputMap = <dynamic, NodeEvaluation>{};
      for (final entry in nodeGraph.getSourceReferencesNodes(node).entries) {
        NodeEvaluation evaluation;
        if (_evaluations.containsKey(entry.value.value)) {
          evaluation = _evaluations[entry.value.value];
        } else {
          allInputsEvaluated = false;
          evaluation = nodeGraph.createNodeEvaluationNot(entry.value.value);
        }
        inputMap[entry.key] = evaluation;
      }

      if (forceEvaluation || allInputsEvaluated) {
        final evaluation = nodeGraph.evaluate(node, inputMap);

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
    _phase = TransactionPhase.COMMIT;

    for (final entry in _evaluations.entries) {
      nodeGraph.commit(entry.key, entry.value.value);
    }
  }

  void _publishValue() {
    _phase = TransactionPhase.PUBLISH;

    for (final entry in _evaluations.entries) {
      nodeGraph.publish(entry.key, entry.value.value);
    }
  }

  void _notifyClosingTransaction() {
    _phase = TransactionPhase.CLOSING;

    for (final handler in _globalListenNodes.values) {
      handler(this);
    }
  }
}
