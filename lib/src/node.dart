import 'dart:async';
import 'dart:collection';

import 'package:frappe/src/reference.dart';

int _nodeId = 0;
final Set<Node> _globalTargetNodes = Set.identity();
final Set<Node> _globalSourceNodes = Set.identity();
const String transactionZoneParameter = 'transaction';

void assertAllNodesUnlinked() {
  if (_globalSourceNodes.isNotEmpty || _globalTargetNodes.isNotEmpty) {
    print('Source nodes: ${_globalSourceNodes}');
    print('Target nodes: ${_globalTargetNodes}');

    throw AssertionError('Not all nodes unlinked');
  }
}

enum TransactionPhase { OPENED, EVALUATION, COMMIT, PUBLISH, CLOSED }

class NodeEvaluation<S> {
  final S _value;

  final bool isEvaluated;

  NodeEvaluation(this._value) : isEvaluated = true;

  NodeEvaluation.not()
      : isEvaluated = false,
        _value = null;

  bool get isNotEvaluated => !isEvaluated;

  S get value => isEvaluated ? _value : throw StateError('Not evaluated');
}

class Transaction {
  static bool get isInTransaction => currentTransaction != null;

  static Transaction get requiredTransaction => currentTransaction != null
      ? currentTransaction
      : throw UnsupportedError('Required explicit transaction');

  static Transaction get currentTransaction {
    final Transaction transaction = Zone.current[transactionZoneParameter];

    return transaction != null && transaction.phase != TransactionPhase.CLOSED
        ? transaction
        : null;
  }

  static T run<T>(T Function(Transaction) runner) {
    if (isInTransaction) {
      return runner(currentTransaction);
    } else {
      Transaction transaction;

      try {
        transaction = Transaction();

        final result = runZoned<T>(() {
          final result = runner(transaction);

          transaction._evaluate();

          transaction._commit();

          transaction._publish();

          return result;
        }, zoneValues: {transactionZoneParameter: transaction});
        return result;
      } finally {
        transaction?._close();
      }
    }
  }

  final ReferenceGroup _referenceGroup = ReferenceGroup();

  final Map<Node, dynamic> _evaluations = Map.identity();

  TransactionPhase _phase = TransactionPhase.OPENED;

  TransactionPhase get phase => _phase;

  N node<N extends Node>(N node) {
    reference(node);

    return node;
  }

  void reference<S>(Node<S> node) => addNodeReference(Reference(node));

  void addNodeReference<S>(Reference<Node<S>> reference) =>
      _referenceGroup.add(reference);

  // TODO gestione delle eccezioni con handler in transaction
  void onError(Object error, StackTrace stacktrace) =>
      print('Uncaught error: $error\n $stacktrace');

  bool hasValue(Node node) => _phase == TransactionPhase.OPENED
      ? _evaluations.containsKey(node)
      : throw UnsupportedError(
          'Node value is exposed only in opened transaction phase');

  S getValue<S>(Node<S> node) =>
      hasValue(node) ? _evaluations[node] : throw StateError('Not evaluated');

  void setValue<S>(Node<S> node, S output) {
    if (_phase != TransactionPhase.OPENED) {
      throw UnsupportedError(
          'Node value is exposed only in opened transaction phase');
    } else if (!node.isReferenced) {
      throw ArgumentError('Node $node is not referenced');
    }

    _evaluations[node] = output;
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

    final pendingNodes = SplayTreeSet<Node>((node1, node2) =>
        node2._evaluationPriority - node1._evaluationPriority);

    for (final sourceNode in List.of(_evaluations.keys)) {
      _evaluateTargetNodes(sourceNode, pendingNodes);
    }

    while (pendingNodes.isNotEmpty) {
      final pendingNode = pendingNodes.first;
      pendingNodes.remove(pendingNode);

      _evaluateNode(pendingNode, pendingNodes, forceEvaluation: true);
    }
  }

  void _commit() {
    _phase = TransactionPhase.COMMIT;

    for (final entry in _evaluations.entries) {
      entry.key._commit(entry.value);
    }
  }

  void _publish() {
    _phase = TransactionPhase.PUBLISH;

    for (final entry in _evaluations.entries) {
      entry.key._publish(entry.value);
    }
  }

  void _evaluateTargetNodes(Node sourceNode, Set<Node> pendingNodes) {
    for (final targetNode in sourceNode._targetNodes.keys) {
      _evaluateNode(targetNode, pendingNodes);
    }
  }

  void _evaluateNode(Node node, Set<Node> pendingNodes,
      {bool forceEvaluation = false}) {
    final inputMap = Map.fromIterable(
        node._sourceReferences.entries
            .where((entry) => _evaluations.containsKey(entry.value.value)),
        key: (entry) => entry.key,
        value: (entry) => _evaluations[entry.value.value]);

    if (forceEvaluation || inputMap.length == node._sourceReferences.length) {
      final evaluation = node._evaluate(inputMap);

      if (evaluation.isEvaluated) {
        _evaluations[node] = evaluation.value;

        _evaluateTargetNodes(node, pendingNodes);
      }
    } else if (node._canEvaluatePartially) {
      pendingNodes.add(node);
    }
  }
}

abstract class Node<S> extends Referenceable {
  bool _canEvaluatePartially;

  final String _debugLabel;

  NodeEvaluation<S> Function(Map inputs) _evaluateHandler;

  void Function(S) _commitHandler;

  void Function(S) _publishHandler;

  final Map<dynamic, HostedReference<Node>> _sourceReferences = Map.identity();

  final Map<Node, Set> _targetNodes = Map.identity();

  int _evaluationPriority;

  Node({
    String debugLabel,
    bool canEvaluatePartially = false,
    NodeEvaluation<S> Function(Map inputs) evaluateHandler,
    void Function(S) commitHandler,
    void Function(S) publishHandler,
  })  : _debugLabel = '${debugLabel ?? 'node'}:${_nodeId++}',
        _canEvaluatePartially = canEvaluatePartially,
        _evaluateHandler = evaluateHandler,
        _commitHandler = commitHandler,
        _publishHandler = publishHandler {
    _evaluationPriority = _canEvaluatePartially ? 1 : 0;
  }

  @override
  String toString() =>
      '[$_debugLabel:$runtimeType:${isReferenced ? 'REFERENCED' : 'UNREFERENCED'}:$_evaluationPriority]';

  void _linkSource(key, Node source) {
    if (!isReferenced) {
      throw ArgumentError('Unreferenced target node');
    }

    source._checkCycle(this);
    final sourceReference = reference(source);
    if (_sourceReferences.isEmpty) {
      _globalTargetNodes.add(this);
    }
    _sourceReferences[key] = sourceReference;
    source._linkTarget(this, key);
  }

  void _unlinkSource(key) {
    final sourceReference = _sourceReferences.remove(key);
    if (sourceReference != null) {
      if (_sourceReferences.isEmpty) {
        _globalTargetNodes.remove(this);
      }
      sourceReference.dispose();
      sourceReference.value._unlinkTarget(this, key);
    }
  }

  void _linkTarget(Node target, key) {
    if (_targetNodes.isEmpty) {
      _globalSourceNodes.add(this);
    }
    _targetNodes.putIfAbsent(target, () => Set.identity()).add(key);

    _propagatePriority(target._evaluationPriority);
  }

  void _unlinkTarget(Node target, key) {
    final keys = _targetNodes[target];
    if (keys != null) {
      keys.remove(key);
      if (keys.isEmpty) {
        _targetNodes.remove(target);
        if (_targetNodes.isEmpty) {
          _globalSourceNodes.remove(this);
        }
      }

      _propagatePriority(-target._evaluationPriority);
    }
  }

  void _checkCycle(Node ascendant) {
    if (ascendant != this) {
      for (final sourceReference in _sourceReferences.values) {
        sourceReference.value._checkCycle(ascendant);
      }
    } else {
      throw ArgumentError('Cycle node link');
    }
  }

  void _propagatePriority(int evaluationPriority) {
    if (evaluationPriority > 0) {
      _evaluationPriority += evaluationPriority;
      for (final sourceReference in _sourceReferences.values) {
        sourceReference.value._propagatePriority(evaluationPriority);
      }
    }
  }

  set evaluateHandler(NodeEvaluation<S> Function(Map inputs) evaluateHandler) {
    if (_evaluateHandler != null) {
      throw StateError('Evaluate handler already defined');
    }

    _evaluateHandler = evaluateHandler;
  }

  set commitHandler(void Function(S) commitHandler) {
    if (_commitHandler != null) {
      throw StateError('Commit handler already defined');
    }

    _commitHandler = commitHandler;
  }

  set publishHandler(void Function(S) publishHandler) {
    if (_publishHandler != null) {
      throw StateError('Publish handler already defined');
    }

    _publishHandler = publishHandler;
  }

  NodeEvaluation<S> _evaluate(Map inputMap) => _evaluateHandler != null
      ? _evaluateHandler(inputMap)
      : throw UnsupportedError('Node evaluation');

  void _commit(S value) => _commitHandler?.call(value);

  void _publish(S value) => _publishHandler?.call(value);
}

class IndexedNode<S> extends Node<S> {
  final List<int> _sourceIndexes = [];
  int _id = 0;

  IndexedNode({
    String debugLabel,
    bool canEvaluatePartially = false,
    NodeEvaluation<S> Function(Map inputs) evaluateHandler,
    void Function(S) commitHandler,
    void Function(S) publishHandler,
  }) : super(
          debugLabel: debugLabel,
          canEvaluatePartially: canEvaluatePartially,
          evaluateHandler: evaluateHandler,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  void link(Node source) {
    _linkSource(_id, source);
    _sourceIndexes.add(_id);
    _id++;
  }

  void unlink(int index) => _unlinkSource(_sourceIndexes.removeAt(index));

  @override
  void onUnreferenced() {
    while (_sourceIndexes.isNotEmpty) {
      unlink(_sourceReferences.keys.last);
    }

    super.onUnreferenced();
  }
}

class NamedNode<S> extends Node<S> {
  NamedNode({
    String debugLabel,
    bool canEvaluatePartially = false,
    NodeEvaluation<S> Function(Map inputs) evaluateHandler,
    void Function(S) commitHandler,
    void Function(S) publishHandler,
  }) : super(
          debugLabel: debugLabel,
          canEvaluatePartially: canEvaluatePartially,
          evaluateHandler: evaluateHandler,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  void link(key, Node source, Transaction transaction) =>
      _linkSource(key, source);

  void unlink(key) => _unlinkSource(key);

  @override
  void onUnreferenced() {
    while (_sourceReferences.isNotEmpty) {
      unlink(_sourceReferences.keys.last);
    }

    super.onUnreferenced();
  }
}
