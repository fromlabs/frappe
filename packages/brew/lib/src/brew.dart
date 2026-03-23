import 'package:frappe/frappe.dart';
import 'package:meta/meta.dart';

/// Public interface for reactive business logic units.
///
/// This is the type used by `BrewProvider` and consumed by the UI layer.
/// It exposes only [dispose] for lifecycle management — all implementation
/// details ([BaseBrew.collect], [BaseBrew.onBind]) live in [BaseBrew].
abstract class Brew {
  /// Releases all resources held by this brew.
  void dispose();
}

/// Base class for [Brew] implementations.
///
/// Subclass [BaseBrew] and implement [onBind] to set up reactive streams
/// and states. Use [collect] to register them for automatic disposal.
abstract class BaseBrew implements Brew {
  BaseBrew() {
    onBind();
  }

  /// Called during construction to initialize reactive streams and states.
  @protected
  void onBind();

  final FrappeReferenceCollector _collector = FrappeReferenceCollector();

  /// Registers a reactive object for automatic disposal and returns it.
  @protected
  FO collect<FO>(FO frappeObject) => _collector.add(frappeObject);

  /// Creates an [EventStreamSink] and registers its stream for disposal.
  ///
  /// Must be called within a transaction.
  @protected
  EventStreamSink<E> collectStreamSink<E>([Merger<E>? sinkMerger]) =>
      _collector.addStreamSink<E>(sinkMerger);

  /// Creates a [ValueStateSink] and registers its state for disposal.
  ///
  /// Must be called within a transaction.
  @protected
  ValueStateSink<V> collectStateSink<V>(V initValue, [Merger<V>? merger]) =>
      _collector.addStateSink<V>(initValue, merger);

  /// Creates an [EventStreamLink] and registers its stream for disposal.
  ///
  /// Must be called within a transaction.
  @protected
  EventStreamLink<E> collectStreamLink<E>() => _collector.addStreamLink<E>();

  /// Creates a [ValueStateLink] and registers its state for disposal.
  ///
  /// Must be called within a transaction.
  @protected
  ValueStateLink<V> collectStateLink<V>() => _collector.addStateLink<V>();

  /// Disposes all collected reactive objects.
  @override
  void dispose() {
    _collector.dispose();
  }
}
