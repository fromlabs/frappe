import '../reference.dart';

import 'node_evaluation_collection.dart';
import 'node_evaluation_list.dart';
import 'node_evaluation_map.dart';
import 'node_evaluation.dart';

typedef NodeHandler<V> = void Function(Node<V> node);
typedef ValueHandler<V> = void Function(V value);
typedef OverrideValueHandler<V> = void Function(
    ValueHandler<V> superCommit, V value);
typedef NodeEvaluator<V> = NodeEvaluation<V> Function(
    Map<dynamic, NodeEvaluation> inputs);
typedef KeyNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationMap inputs);
typedef IndexNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationList inputs);

enum EvaluationType {
  always,
  allInputs,
  almostOneInput,
  firstEvaluation,
  never
}

final nodeGraph = _NodeGraph();

void cleanAllNodesUnlinked() => nodeGraph.cleanAllNodesUnlinked();

void assertAllNodesUnlinked() => nodeGraph.assertAllNodesUnlinked();

class _NodeGraph {
  final Set<Node> _globalTargetNodes = Set.identity();
  final Set<Node> _globalSourceNodes = Set.identity();

  NodeHandler addNodeHandler = (Node node) {};
  NodeHandler removeNodeHandler = (Node node) {};

  Map<Node, Set> getTargetNodes(Node node) => node._targetNodes;

  Map<dynamic, HostedReference<Node>> getSourceReferencesNodes(Node node) =>
      node._sourceReferences;

  void cleanAllNodesUnlinked() {
    _globalSourceNodes.clear();
    _globalTargetNodes.clear();
  }

  void assertAllNodesUnlinked() {
    if (_globalSourceNodes.isNotEmpty || _globalTargetNodes.isNotEmpty) {
      print('Source nodes: ${_globalSourceNodes}');
      print('Target nodes: ${_globalTargetNodes}');

      throw AssertionError('Not all nodes unlinked');
    }
  }

  void addNode(Node node) {
    addNodeHandler(node);
  }

  void removeNode(Node node) {
    removeNodeHandler(node);
  }

  void addTargetNode(Node node) {
    _globalTargetNodes.add(node);
  }

  void removeTargetNode(Node node) {
    _globalTargetNodes.remove(node);
  }

  void addSourceNode(Node node) {
    _globalSourceNodes.add(node);
  }

  void removeSourceNode(Node node) {
    _globalSourceNodes.remove(node);
  }

  NodeEvaluation<S> evaluate<S>(
          Node<S> node, NodeEvaluationCollection inputs) =>
      node._evaluate(inputs);

  void commit<S>(Node<S> node, S value) => node._commit(value);

  void publish<S>(Node<S> node, S value) => node._publish(value);

  void overrideCommit<S>(
      Node<S> node, OverrideValueHandler<S> overrideCommitHandler) {
    final superCommitHandler = node._commitHandler;

    node._commitHandler =
        (S value) => overrideCommitHandler(superCommitHandler, value);
  }

  NodeEvaluationCollection createEvaluationInputs(Node node,
          Iterable<MapEntry<dynamic, NodeEvaluation>> inputEntries) =>
      node._createEvaluationInputs(inputEntries);
}

abstract class Node<S> extends Referenceable {
  static int _nodeId = 0;

  final EvaluationType evaluationType;

  final String debugLabel;

  final Map<dynamic, HostedReference<Node>> _sourceReferences = Map.identity();

  final Map<Node, Set> _targetNodes = Map.identity();

  ValueHandler<S> _commitHandler;

  ValueHandler<S> _publishHandler;

  int _evaluationPriority;

  Node({
    String debugLabel,
    EvaluationType evaluationType,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
  })  : debugLabel = '${debugLabel ?? 'node'}:${_nodeId++}',
        this.evaluationType = evaluationType {
    _commitHandler = commitHandler ?? (S value) {};
    _publishHandler = publishHandler ?? (S value) {};
    _evaluationPriority = evaluationType == EvaluationType.allInputs ? 0 : 1;

    nodeGraph.addNode(this);
  }

  int get evaluationPriority => _evaluationPriority;

  bool get isLinked => _sourceReferences.isNotEmpty;

  @override
  void onUnreferenced() {
    nodeGraph.removeNode(this);

    super.onUnreferenced();
  }

  @override
  String toString() =>
      '[$debugLabel:$runtimeType:${isReferenced ? 'REFERENCED' : 'UNREFERENCED'}:$_evaluationPriority]';

  void _linkSource(key, Node source) {
    assert(key != null);

    if (isUnreferenced) {
      throw ArgumentError('Unreferenced target node');
    } else if (source.isUnreferenced) {
      throw ArgumentError('Unreferenced source node');
    }

    source._checkCycle(this);
    final sourceReference = reference(source);
    if (_sourceReferences.isEmpty) {
      nodeGraph.addTargetNode(this);
    }
    _sourceReferences[key] = sourceReference;
    source._linkTarget(this, key);
  }

  void _unlinkSource(key) {
    final sourceReference = _sourceReferences.remove(key);
    if (sourceReference != null) {
      if (_sourceReferences.isEmpty) {
        nodeGraph.removeTargetNode(this);
      }
      sourceReference.dispose();
      sourceReference.value._unlinkTarget(this, key);
    }
  }

  void _linkTarget(Node target, key) {
    if (_targetNodes.isEmpty) {
      nodeGraph.addSourceNode(this);
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
          nodeGraph.removeSourceNode(this);
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

  NodeEvaluationCollection _createEvaluationInputs(
      Iterable<MapEntry<dynamic, NodeEvaluation>> inputEntries);

  NodeEvaluation<S> _evaluate(covariant NodeEvaluationCollection inputs);

  void _commit(S value) => _commitHandler(value);

  void _publish(S value) => _publishHandler(value);
}

class IndexNode<S> extends Node<S> {
  final IndexNodeEvaluator<S> _evaluateHandler;

  IndexNode({
    String debugLabel,
    EvaluationType evaluationType = EvaluationType.allInputs,
    IndexNodeEvaluator<S> evaluateHandler,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
  })  : _evaluateHandler = evaluateHandler,
        super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  void link(Iterable<Node> sources) {
    if (isLinked) {
      throw StateError('Sources already linked');
    }

    for (final source in sources) {
      _linkSource(_sourceReferences.length, source);
    }
  }

  void unlink() {
    while (isLinked) {
      _unlinkSource(_sourceReferences.keys.last);
    }
  }

  @override
  void onUnreferenced() {
    unlink();

    super.onUnreferenced();
  }

  @override
  NodeEvaluationList _createEvaluationInputs(
          Iterable<MapEntry<dynamic, NodeEvaluation>> inputEntries) =>
      NodeEvaluationList(inputEntries.map((entry) => entry.value != null
          ? entry
          : MapEntry(entry.key, NodeEvaluation<S>.not())));

  @override
  NodeEvaluation<S> _evaluate(NodeEvaluationList inputs) =>
      _evaluateHandler(inputs);
}

class KeyNode<S> extends Node<S> {
  final KeyNodeEvaluator<S> _evaluateHandler;

  KeyNode({
    String debugLabel,
    EvaluationType evaluationType = EvaluationType.allInputs,
    KeyNodeEvaluator<S> evaluateHandler,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
  })  : _evaluateHandler = evaluateHandler,
        super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  bool isLinkedKey({key}) =>
      _sourceReferences.containsKey(key ?? defaultEvaluationKey);

  void link(Node source, {key}) {
    if (isLinkedKey(key: key)) {
      throw StateError('Source on $key already linked');
    }

    _linkSource(key ?? defaultEvaluationKey, source);
  }

  void unlink({key}) => _unlinkSource(key ?? defaultEvaluationKey);

  @override
  void onUnreferenced() {
    while (isLinked) {
      unlink(key: _sourceReferences.keys.last);
    }

    super.onUnreferenced();
  }

  @override
  NodeEvaluationMap _createEvaluationInputs(
          Iterable<MapEntry<dynamic, NodeEvaluation>> inputEntries) =>
      NodeEvaluationMap(inputEntries.map((entry) => entry.value != null
          ? entry
          : MapEntry(entry.key, NodeEvaluation<S>.not())));

  @override
  NodeEvaluation<S> _evaluate(NodeEvaluationMap inputs) =>
      _evaluateHandler(inputs);
}
