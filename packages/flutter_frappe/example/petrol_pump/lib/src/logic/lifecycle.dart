import 'package:frappe/frappe.dart';

import '../model.dart';

EventStream<Fuel> _whenLifted(
        EventStream<UpDown> nozzleStream, Fuel nozzleFuel) =>
    nozzleStream.where((nozzle) => nozzle == UpDown.up).mapTo(nozzleFuel);

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
  final EventStream<Fuel> startStream;
  final EventStream<Unit> endStream;
  final ValueState<Fuel?> fillActiveState;

  factory Lifecycle({
    required EventStream<UpDown> nozzle1Stream,
    required EventStream<UpDown> nozzle2Stream,
    required EventStream<UpDown> nozzle3Stream,
  }) {
    final fillActiveStateRef = ValueStateLink<Fuel?>();

    // A nozzle can only start filling if no other nozzle is already active.
    final startStream = _whenLifted(nozzle1Stream, Fuel.one)
        .orElses([
          _whenLifted(nozzle2Stream, Fuel.two),
          _whenLifted(nozzle3Stream, Fuel.three),
        ])
        .snapshot<Fuel?, Fuel?>(
            fillActiveStateRef.state,
            (newFuel, fillActive) =>
                fillActive == null ? newFuel : null)
        .mapWhereNotNull();

    final endStream =
        _whenSetDown(nozzle1Stream, Fuel.one, fillActiveStateRef.state)
            .orElses([
      _whenSetDown(nozzle2Stream, Fuel.two, fillActiveStateRef.state),
      _whenSetDown(nozzle3Stream, Fuel.three, fillActiveStateRef.state),
    ]);

    // Fill active tracks which nozzle is up; cleared on end, set on start.
    fillActiveStateRef.connect(endStream
        .mapTo<Fuel?>(null)
        .orElse(startStream.map<Fuel?>((e) => e))
        .toState(null));

    return Lifecycle._(
      startStream: startStream,
      endStream: endStream,
      fillActiveState: fillActiveStateRef.state,
    );
  }

  Lifecycle._({
    required this.startStream,
    required this.endStream,
    required this.fillActiveState,
  });
}
