import 'package:meta/meta.dart';

final Map<Referenceable, Set<Reference>> _globalReferences = Map.identity();

void cleanAllUnreferenced() {
  _globalReferences.clear();
}

void assertAllUnreferenced() {
  if (_globalReferences.isNotEmpty) {
    print('References: ${_globalReferences}');

    throw AssertionError('Not all values unreferenced');
  }
}

class ReferenceGroup {
  final Set<Reference> _references = Set.identity();

  bool _isDisposed = false;

  Reference<R> reference<R>(R value) => add(Reference(value));

  Reference<R> add<R>(Reference<R> reference) {
    _checkDisposed();

    _references.add(reference);

    return reference;
  }

  void remove(Reference reference) {
    _checkDisposed();

    _references.remove(reference);
  }

  bool get isDisposed => _isDisposed;

  void dispose() {
    _checkDisposed();

    _isDisposed = true;

    while (_references.isNotEmpty) {
      final last = _references.last;
      _references.remove(last);
      last.dispose();
    }
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Reference group is disposed');
    }
  }
}

class Reference<R> {
  final R value;

  bool _isDisposed = false;

  Reference(R value) : this.value = value {
    ArgumentError.checkNotNull(value, 'value');

    if (value is Referenceable) {
      _registerReference<Referenceable>(value);
    }
  }

  bool get isDisposed => _isDisposed;

  void dispose() {
    _checkDisposed();

    _isDisposed = true;

    final value = this.value;
    if (value is Referenceable) {
      _unregisterReference<Referenceable>(value);
    }
  }

  @override
  String toString() => '#$value';

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Reference is disposed');
    }
  }

  void _registerReference<RR extends Referenceable>(RR value) {
    _globalReferences.putIfAbsent(value, () => Set.identity()).add(this);

    value._refresh();
  }

  void _unregisterReference<RR extends Referenceable>(RR value) {
    final references = _globalReferences[value];
    references.remove(this);
    if (references.isEmpty) {
      _globalReferences.remove(value);
    }

    value._refresh();
  }
}

class HostedReference<R> extends Reference<R> {
  final Referenceable _host;

  HostedReference(this._host, R value) : super(value) {
    ArgumentError.checkNotNull(_host, 'host');

    if (!_host.isReferenced) {
      throw ArgumentError('Unreferenced host: $_host');
    }
  }

  @override
  String toString() => '#$_host.$value';

  @override
  void _unregisterReference<RR extends Referenceable>(RR value) {
    _host._removeHostedReference(this);

    super._unregisterReference(value);
  }
}

abstract class Referenceable {
  final ReferenceGroup _hostedGroup = ReferenceGroup();

  bool _isReferenced = false;

  bool get isReferenced => _isReferenced;

  bool get isUnreferenced => !_isReferenced;

  HostedReference<R> reference<R>(R value) {
    _hostedGroup._checkDisposed();

    return _hostedGroup.add(HostedReference(this, value));
  }

  @protected
  void onUnreferenced() {
    if (!_hostedGroup.isDisposed) {
      _hostedGroup.dispose();
    }
  }

  void _removeHostedReference(HostedReference reference) {
    if (!_hostedGroup.isDisposed) {
      _hostedGroup.remove(reference);
    }
  }

  void _refresh() {
    _isReferenced = _checkReferenced(this, Set.identity());

    if (!_isReferenced) {
      onUnreferenced();
    }
  }

  bool _checkReferenced(Referenceable referenceable, [Set<Reference> visited]) {
    final references = _globalReferences[referenceable];
    if (references != null && references.isNotEmpty) {
      for (final reference in references) {
        if (reference is HostedReference) {
          if (!visited.contains(reference)) {
            visited.add(reference);

            if (_checkReferenced(reference._host, visited)) {
              return true;
            }
          }
        } else {
          return true;
        }
      }
    }

    return false;
  }
}
