import 'package:meta/meta.dart';

class ReferenceGroup {
  final Set<Reference> _references = Set.identity();

  bool _isDisposed = false;

  Reference add(Reference reference) {
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

class Reference<R extends Referenceable> {
  final R value;

  bool _isDisposed = false;

  Reference(this.value) {
    ArgumentError.checkNotNull(value, 'value');

    value._registerReference(this);
  }

  bool get isDisposed => _isDisposed;

  void dispose() {
    _checkDisposed();

    _isDisposed = true;

    value._unregisterReference(this);
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Reference is disposed');
    }
  }
}

class SlaveReference<R extends Referenceable> extends Reference<R> {
  final Referenceable _master;

  SlaveReference(R value, {@required Referenceable master})
      : _master = master,
        super(value) {
    ArgumentError.checkNotNull(master, 'master');

    if (!value.isReferenced) {
      throw ArgumentError('Unreferenced slave');
    }
  }
}

abstract class Referenceable {
  static final Map<Referenceable, Set<Reference>> _globalReferences =
      Map.identity();

  final ReferenceGroup _slaveGroup = ReferenceGroup();

  bool _isReferenced = false;

  SlaveReference addSlave(Referenceable slave) =>
      _slaveGroup.add(SlaveReference(slave, master: this));

  void removeSlave(SlaveReference slaveReference) =>
      _slaveGroup.remove(slaveReference);

  bool get isReferenced => _isReferenced;

  @protected
  void onUnreferenced() {
    if (!_slaveGroup.isDisposed) {
      _slaveGroup.dispose();
    }
  }

  void _registerReference(Reference reference) {
    _globalReferences.putIfAbsent(this, () => Set.identity()).add(reference);

    _refresh();
  }

  void _unregisterReference(Reference reference) {
    final references = _globalReferences[this];

    references.remove(reference);

    if (references.isEmpty) {
      _globalReferences.remove(this);
    }

    _refresh();
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
        if (reference is SlaveReference) {
          if (!visited.contains(reference)) {
            visited.add(reference);
            if (_checkReferenced(reference._master, visited)) {
              return true;
            }
          }
        } else {
          return true;
        }
      }
      return false;
    } else {
      return false;
    }
  }
}
