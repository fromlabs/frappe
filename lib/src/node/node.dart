import 'package:meta/meta.dart';

import '../reference.dart';
import 'node_evaluation.dart';

typedef NodeHandler<V> = void Function(Node<V> node);
typedef ValueHandler<V> = void Function(V value);
typedef OverrideValueHandler<V> = void Function(
    ValueHandler<V> superCommit, V value);
typedef NodeEvaluator<V> = NodeEvaluation<V> Function(
    Map<dynamic, NodeEvaluation> inputs);

enum EvaluationType { ALL_INPUTS, ALMOST_ONE_INPUT, FIRST_EVALUATION }

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

  NodeEvaluation<S> createNodeEvaluationNot<S>(Node<S> node) =>
      node._nodeEvaluationNot;

  NodeEvaluation<S> evaluate<S>(
          Node<S> node, Map<dynamic, NodeEvaluation> inputMap) =>
      node._evaluate(inputMap);

  void commit<S>(Node<S> node, S value) => node._commit(value);

  void publish<S>(Node<S> node, S value) => node._publish(value);

  void overrideCommit<S>(
      Node<S> node, OverrideValueHandler<S> overrideCommitHandler) {
    final superCommitHandler = node._commitHandler;

    node._commitHandler =
        (S value) => overrideCommitHandler(superCommitHandler, value);
  }
}

abstract class Node<S> extends Referenceable {
  static int _nodeId = 0;

  final EvaluationType evaluationType;

  final String debugLabel;

  final Map<dynamic, HostedReference<Node>> _sourceReferences = Map.identity();

  final Map<Node, Set> _targetNodes = Map.identity();

  NodeEvaluator<S> _evaluateHandler;

  ValueHandler<S> _commitHandler;

  ValueHandler<S> _publishHandler;

  int _evaluationPriority;

  Node({
    String debugLabel,
    EvaluationType evaluationType,
    @required NodeEvaluator<S> evaluateHandler,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
  })  : debugLabel = '${debugLabel ?? 'node'}:${_nodeId++}',
        this.evaluationType = evaluationType,
        _evaluateHandler = evaluateHandler {
    _commitHandler = commitHandler ?? (S value) {};
    _publishHandler = publishHandler ?? (S value) {};
    _evaluationPriority = evaluationType == EvaluationType.ALL_INPUTS ? 0 : 1;

    nodeGraph.addNode(this);
  }

  int get evaluationPriority => _evaluationPriority;

  @override
  void onUnreferenced() {
    nodeGraph.removeNode(this);

    super.onUnreferenced();
  }

  @override
  String toString() =>
      '[$debugLabel:$runtimeType:${isReferenced ? 'REFERENCED' : 'UNREFERENCED'}:$_evaluationPriority]';

  NodeEvaluation<S> get _nodeEvaluationNot => NodeEvaluation.not();

  void _linkSource(key, Node source) {
    if (!isReferenced) {
      throw ArgumentError('Unreferenced target node');
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

  NodeEvaluation<S> _evaluate(Map<dynamic, NodeEvaluation> inputMap) =>
      _evaluateHandler(inputMap);

  void _commit(S value) => _commitHandler(value);

  void _publish(S value) => _publishHandler(value);
}

class IndexNode<S> extends Node<S> {
  final List<int> _sourceIndexes = [];
  int _id = 0;

  IndexNode({
    String debugLabel,
    EvaluationType evaluationType = EvaluationType.ALL_INPUTS,
    NodeEvaluator<S> evaluateHandler,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
  }) : super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          evaluateHandler: evaluateHandler,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  bool isLinked(int index) => _sourceIndexes.length > index;

  // TODO link iterable
  void link(Node source) {
    _linkSource(_id, source);
    _sourceIndexes.add(_id);
    _id++;
  }

  // TODO unlinkall
  void unlink() {
    _unlinkSource(_sourceIndexes.removeLast());
    _id--;
  }

  @override
  void onUnreferenced() {
    while (_sourceIndexes.isNotEmpty) {
      unlink();
    }

    super.onUnreferenced();
  }
}

class KeyNode<S> extends Node<S> {
  KeyNode({
    String debugLabel,
    EvaluationType evaluationType = EvaluationType.ALL_INPUTS,
    NodeEvaluator<S> evaluateHandler,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
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
