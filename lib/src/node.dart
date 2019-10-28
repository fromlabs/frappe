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

class Transaction {
  final ReferenceGroup _referenceGroup = ReferenceGroup();

  final Map<Node, dynamic> _evaluations = Map.identity();

  bool _isClosed = false;

  bool get isClosed => _isClosed;

  static bool get isInTransaction => currentTransaction != null;

  static Transaction get currentTransaction {
    final Transaction transaction = Zone.current[transactionZoneParameter];

    return transaction != null && !transaction.isClosed ? transaction : null;
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

          return result;
        }, zoneValues: {transactionZoneParameter: transaction});
        return result;
      } finally {
        transaction?._close();
      }
    }
  }

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

  bool isEvaluated(Node node) => _evaluations.containsKey(node);

  S getEvaluation<S>(Node<S> node) => isEvaluated(node)
      ? _evaluations[node]
      : throw StateError('Not evaluated');

  void setEvaluation<S>(Node<S> node, S output) {
    if (!node.isReferenced) {
      throw ArgumentError('Node $node is not referenced');
    }

    _evaluations[node] = output;
  }

  void _close() {
    if (_isClosed) {
      throw StateError('Transaction is closed');
    }

    _referenceGroup.dispose();

    _isClosed = true;
  }

  void _evaluate() {
    print('--> Evaluation: $_propagationCount');

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

    _evaluations.forEach((node, value) => print('$node = $value'));
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
            .where((entry) => isEvaluated(entry.value.value)),
        key: (entry) => entry.key,
        value: (entry) => getEvaluation(entry.value.value));

    if (forceEvaluation || inputMap.length == node._sourceReferences.length) {
      final output = node._evaluateInputs(inputMap);

      setEvaluation(node, output);

      _evaluateTargetNodes(node, pendingNodes);
    } else if (node._canEvaluatePartially) {
      pendingNodes.add(node);
    }
  }
}

// TODO possibilità di registrare un handler onTransactionBegin sul nodo
// TODO possibilità di registrare un handler onTransactionEnd sul nodo
abstract class Node<S> extends Referenceable {
  bool _canEvaluatePartially;

  final String _debugLabel;

  final S Function(Map inputs) _evaluate;

  final Map<dynamic, HostedReference<Node>> _sourceReferences = Map.identity();

  final Map<Node, Set> _targetNodes = Map.identity();

  int _evaluationPriority;

  Node(
      {String debugLabel,
      bool canEvaluatePartially = false,
      S Function(Map inputs) evaluate})
      : _debugLabel = '${debugLabel ?? 'node'}:${_nodeId++}',
        _canEvaluatePartially = canEvaluatePartially,
        _evaluate = evaluate {
    _evaluationPriority = _canEvaluatePartially ? 1 : 0;
  }

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

  @override
  String toString() =>
      '[$_debugLabel:$runtimeType:${isReferenced ? 'REFERENCED' : 'UNREFERENCED'}:$_evaluationPriority]';

  S _evaluateInputs(Map inputMap) => _evaluate(inputMap);

  void _propagatePriority(int evaluationPriority) {
    _propagationCount++;
    _evaluationPriority += evaluationPriority;
    for (final sourceReference in _sourceReferences.values) {
      sourceReference.value._propagatePriority(evaluationPriority);
    }
  }
}

int _propagationCount = 0;

class IndexedNode<S> extends Node<S> {
  final List<int> _sourceIndexes = [];
  int _id = 0;

  IndexedNode(
      {String debugLabel,
      bool canEvaluatePartially = false,
      S Function(Map inputs) evaluate})
      : super(
            debugLabel: debugLabel,
            canEvaluatePartially: canEvaluatePartially,
            evaluate: evaluate);

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
  NamedNode(
      {String debugLabel,
      bool canEvaluatePartially = false,
      S Function(Map inputs) evaluate})
      : super(
            debugLabel: debugLabel,
            canEvaluatePartially: canEvaluatePartially,
            evaluate: evaluate);

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
