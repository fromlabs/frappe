import 'dart:async';
import 'dart:collection';
import 'package:meta/meta.dart';

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

enum EvaluationType { ALL_INPUTS, ALMOST_ONE_INPUT, FIRST_EVALUATION }

class NodeEvaluation<S> {
  final S _value;

  final bool isEvaluated;

  NodeEvaluation(this._value) : isEvaluated = true;

  NodeEvaluation.not()
      : isEvaluated = false,
        _value = null;

  bool get isNotEvaluated => !isEvaluated;

  S get value => isEvaluated ? _value : throw StateError('Not evaluated');

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    } else {
      return other is NodeEvaluation<S> &&
          isEvaluated == other.isEvaluated &&
          _value == other._value;
    }
  }

  @override
  int get hashCode => _jf(_jc(_jc(0, isEvaluated.hashCode), _value.hashCode));

  @override
  String toString() =>
      '${isEvaluated ? 'NodeEvaluation($_value)' : 'NodeEvaluation.not()'}';
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

  static T runRequired<T>(T Function(Transaction) runner) =>
      runner(requiredTransaction);

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

  final Map<Node, NodeEvaluation> _evaluations = Map.identity();

  final Set<Node> _firstNodes = Set.identity();

  final Set<Node> _pendingNodes = SplayTreeSet<Node>(
      (node1, node2) => node2._evaluationPriority - node1._evaluationPriority);

  TransactionPhase _phase = TransactionPhase.OPENED;

  TransactionPhase get phase => _phase;

  N node<N extends Node>(N node) {
    reference(node);

    return node;
  }

  void reference<S>(Node<S> node) => addNodeReference(Reference(node));

  void addNodeReference<S>(Reference<Node<S>> reference) {
    if (reference.value._evaluationType == EvaluationType.FIRST_EVALUATION) {
      _firstNodes.add(reference.value);
    }

    _referenceGroup.add(reference);
  }

  // TODO gestione delle eccezioni con handler in transaction
  void onError(Object error, StackTrace stacktrace) =>
      print('Uncaught error: $error\n $stacktrace');

  bool hasValue(Node node) => _phase == TransactionPhase.OPENED
      ? _evaluations.containsKey(node)
      : throw UnsupportedError(
          'Node value is exposed only in opened transaction phase');

  S getValue<S>(Node<S> node) => hasValue(node)
      ? _evaluations[node].value
      : throw StateError('Not evaluated');

  void setValue<S>(Node<S> node, S output) {
    if (_phase != TransactionPhase.OPENED) {
      throw UnsupportedError(
          'Node value is exposed only in opened transaction phase');
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

  void _evaluatePendingNodes() {
    while (_pendingNodes.isNotEmpty) {
      final pendingNode = _pendingNodes.first;
      _pendingNodes.remove(pendingNode);

      _evaluateNode(pendingNode, forceEvaluation: true);
    }
  }

  void _commit() {
    _phase = TransactionPhase.COMMIT;

    for (final entry in _evaluations.entries) {
      entry.key._commit(entry.value.value);
    }
  }

  void _publish() {
    _phase = TransactionPhase.PUBLISH;

    for (final entry in _evaluations.entries) {
      entry.key._publish(entry.value.value);
    }
  }

  void _evaluateTargetNodes(Node sourceNode) {
    for (final targetNode in sourceNode._targetNodes.keys) {
      _evaluateNode(targetNode);
    }
  }

  void _evaluateNode(Node node, {bool forceEvaluation = false}) {
    assert(!_evaluations.containsKey(node));

    bool allInputsEvaluated = true;
    final inputMap = <dynamic, NodeEvaluation>{};
    for (final entry in node._sourceReferences.entries) {
      NodeEvaluation evaluation;
      if (_evaluations.containsKey(entry.value.value)) {
        evaluation = _evaluations[entry.value.value];
      } else {
        allInputsEvaluated = false;
        evaluation = NodeEvaluation.not();
      }
      inputMap[entry.key] = evaluation;
    }

    if (forceEvaluation || allInputsEvaluated) {
      final evaluation = node._evaluate(inputMap);

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

abstract class Node<S> extends Referenceable {
  final EvaluationType _evaluationType;

  final String _debugLabel;

  NodeEvaluation<S> Function(Map<dynamic, NodeEvaluation> inputs)
      evaluateHandler;

  void Function(S) commitHandler;

  void Function(S) publishHandler;

  final Map<dynamic, HostedReference<Node>> _sourceReferences = Map.identity();

  final Map<Node, Set> _targetNodes = Map.identity();

  int _evaluationPriority;

  Node({
    String debugLabel,
    EvaluationType evaluationType,
    @required
        NodeEvaluation<S> Function(Map<dynamic, NodeEvaluation> inputs)
            evaluateHandler,
    void Function(S) commitHandler,
    void Function(S) publishHandler,
  })  : _debugLabel = '${debugLabel ?? 'node'}:${_nodeId++}',
        _evaluationType = evaluationType,
        this.evaluateHandler = evaluateHandler,
        this.commitHandler = commitHandler ?? ((_) {}),
        this.publishHandler = publishHandler ?? ((_) {}) {
    _evaluationPriority = _evaluationType == EvaluationType.ALL_INPUTS ? 0 : 1;
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

  NodeEvaluation<S> _evaluate(Map<dynamic, NodeEvaluation> inputMap) =>
      evaluateHandler(inputMap);

  void _commit(S value) => commitHandler.call(value);

  void _publish(S value) => publishHandler.call(value);
}

class IndexedNode<S> extends Node<S> {
  final List<int> _sourceIndexes = [];
  int _id = 0;

  IndexedNode({
    String debugLabel,
    EvaluationType evaluationType = EvaluationType.ALL_INPUTS,
    NodeEvaluation<S> Function(Map<dynamic, NodeEvaluation> inputs)
        evaluateHandler,
    void Function(S) commitHandler,
    void Function(S) publishHandler,
  }) : super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          evaluateHandler: evaluateHandler,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  bool isLinked(int index) => _sourceIndexes.length > index;

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
    EvaluationType evaluationType = EvaluationType.ALL_INPUTS,
    NodeEvaluation<S> Function(Map<dynamic, NodeEvaluation> inputs)
        evaluateHandler,
    void Function(S) commitHandler,
    void Function(S) publishHandler,
  }) : super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          evaluateHandler: evaluateHandler,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  void link(key, Node source) => _linkSource(key, source);

  void unlink(key) => _unlinkSource(key);

  @override
  void onUnreferenced() {
    while (_sourceReferences.isNotEmpty) {
      unlink(_sourceReferences.keys.last);
    }

    super.onUnreferenced();
  }
}

int _jc(int hash, int value) {
  hash = 0x1fffffff & (hash + value);
  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
  return hash ^ (hash >> 6);
}

int _jf(int hash) {
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}
