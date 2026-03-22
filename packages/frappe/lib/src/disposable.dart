import 'dart:async';

/// Interface for objects that hold resources and need cleanup.
abstract interface class Disposable {
  /// Releases all resources held by this object.
  FutureOr<void> dispose();
}
