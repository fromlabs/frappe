/// Flutter integration for the [frappe] FRP library.
///
/// Provides the [Observe] widget, which rebuilds automatically whenever a
/// [ValueState] emits a new value. Use it to bridge frappe's reactive
/// primitives into the Flutter widget tree:
///
/// ```dart
/// final sink = ValueStateSink<int>(0);
///
/// Observe<int>(
///   state: sink.state,
///   builder: (context, value) => Text('$value'),
/// );
/// ```
library;

export 'src/observe.dart';
