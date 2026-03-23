import 'package:frappe/frappe.dart';

import '../model.dart';

/// Filters [nozzleStream] for lift-up events, emitting [nozzleFuel]
/// to indicate which fuel nozzle was lifted.
EventStream<Fuel> _whenLifted(
        EventStream<UpDown> nozzleStream, Fuel nozzleFuel) =>
    nozzleStream.where((nozzle) => nozzle == UpDown.up).mapTo(nozzleFuel);

/// Filters [nozzleStream] for set-down events, emitting [unit] only when
/// [nozzleFuel] matches the currently active fill in [fillActiveState].
EventStream<Unit> _whenSetDown(EventStream<UpDown> nozzleStream,
        Fuel nozzleFuel, ValueState<Fuel?> fillActiveState) =>
    nozzleStream
        .snapshot<Fuel?, Unit?>(
            fillActiveState,
            (fuel, fillActive) => fuel == UpDown.down &&
                    fillActive != null &&
                    fillActive == nozzleFuel
                ? unit
                : null)
        .mapWhereNotNull();

/// Manages the nozzle lifecycle: which fuel is active, start/end events.
class Lifecycle {
  /// Emits the [Fuel] type when a fill begins (nozzle lifted while idle).
  final EventStream<Fuel> startStream;

  /// Emits [unit] when the active fill ends (nozzle set down).
  final EventStream<Unit> endStream;

  /// The currently active fuel, or `null` when no nozzle is lifted.
  final ValueState<Fuel?> fillActiveState;

  factory Lifecycle({
    required EventStream<UpDown> nozzle1Stream,
    required EventStream<UpDown> nozzle2Stream,
    required EventStream<UpDown> nozzle3Stream,
  }) {
    // Fill active tracks which nozzle is up; cleared on end, set on start.
    final (fillActiveState, (startStream, endStream)) =
        ValueState.loopWith((ValueState<Fuel?> self) {
      // A nozzle can only start filling if no other nozzle is already active.
      final start = _whenLifted(nozzle1Stream, Fuel.one)
          .orElses([
            _whenLifted(nozzle2Stream, Fuel.two),
            _whenLifted(nozzle3Stream, Fuel.three),
          ])
          .snapshot<Fuel?, Fuel?>(
              self, (newFuel, fillActive) => fillActive == null ? newFuel : null)
          .mapWhereNotNull();

      final end = _whenSetDown(nozzle1Stream, Fuel.one, self).orElses([
        _whenSetDown(nozzle2Stream, Fuel.two, self),
        _whenSetDown(nozzle3Stream, Fuel.three, self),
      ]);

      return (
        end.mapTo<Fuel?>(null).orElse(start.map<Fuel?>((e) => e)).toState(null),
        (start, end),
      );
    });

    return Lifecycle._(
      startStream: startStream,
      endStream: endStream,
      fillActiveState: fillActiveState,
    );
  }

  Lifecycle._({
    required this.startStream,
    required this.endStream,
    required this.fillActiveState,
  });
}
