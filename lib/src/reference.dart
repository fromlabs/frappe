import 'disposable.dart';
import 'reactive_scope.dart';

/// A group of [Reference]s that can be disposed together.
class ReferenceGroup implements Disposable {
  final Set<Reference> _references = Set.identity();
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  /// Creates and adds a reference to [referenceable].
  Reference<R> reference<R extends Referenceable>(R referenceable) =>
      add(Reference(referenceable));

  /// Adds an existing [reference] to this group.
  R add<R extends Reference>(R reference) {
    _checkDisposed();
    _references.add(reference);
    return reference;
  }

  /// Removes a [reference] from this group without disposing it.
  void remove(Reference reference) {
    _checkDisposed();
    _references.remove(reference);
  }

  @override
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
      throw StateError('ReferenceGroup is disposed');
    }
  }
}

/// A reference to a [Referenceable] object that keeps it alive.
///
/// Reference counting determines object lifetime. When all references
/// to a [Referenceable] are disposed, [Referenceable.onUnreferenced] is called.
class Reference<R extends Referenceable> implements Disposable {
  final R value;
  final ReactiveScope _scope;
  bool _isDisposed = false;

  Reference(this.value) : _scope = ReactiveScope.current {
    ArgumentError.checkNotNull(value, 'value');
    _registerReference();
  }

  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _checkDisposed();
    _isDisposed = true;
    _unregisterReference();
  }

  @override
  String toString() => '#$value';

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Reference is disposed');
    }
  }

  void _registerReference() {
    _scope.references
        .putIfAbsent(value, () => Set.identity())
        .add(this);
    value._refresh(_scope);
  }

  void _unregisterReference() {
    final references = _scope.references[value];
    if (references != null) {
      references.remove(this);
      if (references.isEmpty) {
        _scope.references.remove(value);
      }
    }
    value._refresh(_scope);
  }
}

/// A [Reference] that is hosted by another [Referenceable].
///
/// When the host loses all references, hosted references are also cleaned up.
class HostedReference<R extends Referenceable> extends Reference<R> {
  final Referenceable _host;

  HostedReference(this._host, R value) : super(value) {
    if (!_host.isReferenced) {
      throw ArgumentError('Unreferenced host');
    }
  }

  @override
  String toString() => '#$_host.$value';

  @override
  void _unregisterReference() {
    _host._removeHostedReference(this);
    super._unregisterReference();
  }
}

/// Mixin for objects that participate in reference counting.
///
/// A [Referenceable] is considered "alive" as long as at least one
/// non-hosted [Reference] transitively points to it. When the last
/// such reference is disposed, [onUnreferenced] is called.
abstract class Referenceable {
  final ReferenceGroup _hostedGroup = ReferenceGroup();
  bool _isReferenced = false;

  /// Whether this object has any active references.
  bool get isReferenced => _isReferenced;

  /// Creates a hosted reference from this object to [value].
  ///
  /// The [value] will be kept alive as long as this object is referenced.
  HostedReference<R> reference<R extends Referenceable>(R value) {
    _hostedGroup._checkDisposed();
    return _hostedGroup.add(HostedReference(this, value));
  }

  /// Called when this object loses all references.
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

  void _refresh(ReactiveScope scope) {
    _isReferenced = _checkReferenced(this, scope, Set.identity());
    if (!_isReferenced) {
      onUnreferenced();
    }
  }

  bool _checkReferenced(
      Referenceable referenceable, ReactiveScope scope, Set<Reference> visited) {
    final references = scope.references[referenceable];
    if (references != null && references.isNotEmpty) {
      for (final reference in references) {
        if (reference is HostedReference) {
          if (!visited.contains(reference)) {
            visited.add(reference);
            if (_checkReferenced(reference._host, scope, visited)) {
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
