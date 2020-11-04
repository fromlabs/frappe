const String defaultEvaluationKey = 'default';

abstract class NodeEvaluation<S> {
  factory NodeEvaluation(S value) => _NodeEvaluation<S>(value);

  factory NodeEvaluation.not() => _NotNodeEvaluation<S>();

  bool get isEvaluated;

  bool get isNotEvaluated;

  S get value;
}

class _NodeEvaluation<S> implements NodeEvaluation<S> {
  @override
  final S value;

  @override
  final bool isEvaluated = true;

  _NodeEvaluation(this.value);

  @override
  bool get isNotEvaluated => !isEvaluated;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    } else {
      return other is _NodeEvaluation<S> && value == value;
    }
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'NodeEvaluation($value)';
}

class _NotNodeEvaluation<S> implements NodeEvaluation<S> {
  @override
  final bool isEvaluated = false;

  const _NotNodeEvaluation();

  @override
  bool get isNotEvaluated => !isEvaluated;

  @override
  S get value => throw StateError('Not evaluated');

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    } else {
      return other is _NodeEvaluation<S>;
    }
  }

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NodeEvaluation.not()';
}
