/// A functional reactive programming library for Dart.
///
/// Frappe provides two core primitives:
/// - [EventStream]: A discrete stream of events over time
/// - [ValueState]: A continuous value that changes over time
///
/// A root [FrappeScope] is always available, so no explicit setup is needed:
///
/// ```dart
/// runTransaction(() {
///   final sink = EventStreamSink<int>();
///   final ref = sink.stream.toReference();
///   sink.send(42);
///   ref.dispose();
/// });
/// ```
///
/// For isolated contexts (e.g., testing), create an explicit scope:
///
/// ```dart
/// final scope = FrappeScope();
/// scope.run(() {
///   runTransaction(() { ... });
///   scope.assertCleanState();
/// });
/// scope.dispose();
/// ```
library;

export 'src/unit.dart';
export 'src/tuple.dart';
export 'src/typedefs.dart';
export 'src/disposable.dart';
export 'src/disposable_collector.dart';
export 'src/listen_subscription.dart';
export 'src/lazy_value.dart';
export 'src/frappe_scope.dart';
export 'src/transaction.dart'
    show Transaction, TransactionPhase, TransactionHandler;
export 'src/node.dart' show EvaluationType;
export 'src/node_evaluation.dart' show NodeEvaluation, Evaluated, NotEvaluated;
export 'src/event_stream.dart'
    show EventStream, EventStreamSink, EventStreamLink;
export 'src/value_state.dart' show ValueState, ValueStateSink, ValueStateLink;
export 'src/frappe_reference.dart';
export 'src/extensions.dart';
