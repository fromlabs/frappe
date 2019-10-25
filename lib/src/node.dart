import 'dart:async';

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

        final result = runZoned<T>(() => runner(transaction),
            zoneValues: {transactionZoneParameter: transaction});

        // TODO evaluation

        return result;
      } finally {
        transaction?._close();
      }
    }
  }

  N node<N extends Node>(N node) => reference(node).value;

  Reference<Node<S>> reference<S>(Node<S> node) =>
      addNodeReference(Reference(node));

  Reference<Node<S>> addNodeReference<S>(Reference<Node<S>> reference) =>
      _referenceGroup.add(reference);

  // TODO gestione delle eccezioni con handler in transaction
  void onError(Object error, StackTrace stacktrace) =>
      print('Uncaught error: $error\n $stacktrace');

  bool isEvaluated(Node node) => _evaluations.containsKey(node);

  S getEvaluation<S>(Node<S> node) => isEvaluated(node)
      ? _evaluations[node]
      : throw StateError('Not evaluated');

  void setEvaluation<S>(Node<S> node, S output) => _evaluations[node] = output;

  void _close() {
    _checkClosed();

    _referenceGroup.dispose();

    _isClosed = true;
  }

  void _checkClosed() {
    if (_isClosed) {
      throw StateError('Transaction is closed');
    }
  }
}

abstract class Node<S> extends Referenceable {
  final String _debugLabel;

  final Map<dynamic, HostedReference<Node>> _sourceReferences = Map.identity();

  final Map<Node, Set> _targetNodes = Map.identity();

  Node({String debugLabel})
      : _debugLabel = '${debugLabel ?? 'node'}:${_nodeId++}';

  void _linkSource(key, Node source) {
    if (!isReferenced) {
      throw ArgumentError('Unreferenced target node');
    }

    source._checkCycle(this);
    if (_sourceReferences.isEmpty) {
      _globalTargetNodes.add(this);
    }
    _sourceReferences[key] = reference(source);
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
      '[$_debugLabel:$runtimeType:${isReferenced ? 'REFERENCED' : 'UNREFERENCED'}]';
}

class IndexedNode<S> extends Node<S> {
  final List<int> _sourceIndexes = [];
  int _id = 0;

  IndexedNode({String debugLabel}) : super(debugLabel: debugLabel);

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
  NamedNode({String debugLabel}) : super(debugLabel: debugLabel);

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
