import 'package:frappe/frappe.dart';

/// Base class for reactive business logic units.
///
/// Subclass [Brew] and implement [onBind] to set up reactive streams
/// and states. Use [collect] to register them for automatic disposal.
abstract class Brew {
  Brew() {
    onBind();
  }

  /// Called during construction to initialize reactive streams and states.
  void onBind();

  final FrappeReferenceCollector _collector = FrappeReferenceCollector();

  /// Registers a reactive object for automatic disposal and returns it.
  FO collect<FO>(FO frappeObject) => _collector.add(frappeObject);

  /// Creates an [EventStreamSink] and registers its stream for disposal.
  ///
  /// Must be called within a transaction.
  EventStreamSink<E> collectStreamSink<E>([Merger<E>? sinkMerger]) =>
      _collector.addStreamSink<E>(sinkMerger);

  /// Creates a [ValueStateSink] and registers its state for disposal.
  ///
  /// Must be called within a transaction.
  ValueStateSink<V> collectStateSink<V>(V initValue, [Merger<V>? merger]) =>
      _collector.addStateSink<V>(initValue, merger);

  /// Creates an [EventStreamLink] and registers its stream for disposal.
  ///
  /// Must be called within a transaction.
  EventStreamLink<E> collectStreamLink<E>() => _collector.addStreamLink<E>();

  /// Creates a [ValueStateLink] and registers its state for disposal.
  ///
  /// Must be called within a transaction.
  ValueStateLink<V> collectStateLink<V>() => _collector.addStateLink<V>();

  /// Disposes all collected reactive objects.
  void dispose() {
    _collector.dispose();
  }
}
