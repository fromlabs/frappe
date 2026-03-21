import 'dart:async';

/// Interface for objects that hold resources and need cleanup.
abstract interface class Disposable {
  FutureOr<void> dispose();
}
