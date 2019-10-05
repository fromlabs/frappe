import 'package:meta/meta.dart';
import 'package:optional/optional.dart';
import 'package:frappe/frappe.dart';
import '../model.dart';
import '../petrol_pump.dart';

EventStream<Fuel> _whenLifted(
        EventStream<UpDown> nozzleStream, Fuel nozzleFuel) =>
    nozzleStream.where((nozzle) => nozzle == UpDown.up).mapTo(nozzleFuel);

EventStream<Unit> _whenSetDown(EventStream<UpDown> nozzleStream,
        Fuel nozzleFuel, OptionalValueState<Fuel> fillActiveState) =>
    nozzleStream
        .snapshot<Optional<Fuel>, Optional<Unit>>(
            fillActiveState,
            (fuel, fillActive) => fuel == UpDown.down &&
                    fillActive.isPresent &&
                    fillActive.value == nozzleFuel
                ? Optional.of(unit)
                : Optional<Unit>.empty())
        .asOptional<Unit>()
        .mapWhereOptional();

class Lifecycle extends BaseObserver {
  final EventStream<Fuel> startStream;

  final EventStream<Unit> endStream;

  final OptionalValueState<Fuel> fillActiveState;
  factory Lifecycle({
    @required EventStream<UpDown> nozzle1Stream,
    @required EventStream<UpDown> nozzle2Stream,
    @required EventStream<UpDown> nozzle3Stream,
  }) {
    final fillActiveStateRef = OptionalValueStateReference<Fuel>();

    final startStream = _whenLifted(nozzle1Stream, Fuel.one)
        .orElses([
          _whenLifted(nozzle2Stream, Fuel.two),
          _whenLifted(nozzle3Stream, Fuel.three)
        ])
        .snapshot<Optional<Fuel>, Optional<Fuel>>(
            fillActiveStateRef.state,
            (newFuel, fillActive) =>
                !fillActive.isPresent ? Optional.of(newFuel) : Optional.empty())
        .asOptional<Fuel>()
        .mapWhereOptional();

    final endStream =
        _whenSetDown(nozzle1Stream, Fuel.one, fillActiveStateRef.state)
            .orElses([
      _whenSetDown(nozzle2Stream, Fuel.two, fillActiveStateRef.state),
      _whenSetDown(nozzle3Stream, Fuel.three, fillActiveStateRef.state)
    ]);

    fillActiveStateRef.link(endStream
        .mapToOptionalEmpty<Fuel>()
        .orElse(startStream.mapToOptionalOf())
        .toState(Optional.empty())
        .asOptional<Fuel>());

    return Lifecycle._(
      startStream: startStream,
      endStream: endStream,
      fillActiveState: fillActiveStateRef.state,
    );
  }
  Lifecycle._({
    this.startStream,
    this.endStream,
    this.fillActiveState,
  });
}
