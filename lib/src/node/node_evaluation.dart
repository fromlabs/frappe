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
