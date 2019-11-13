import 'package:petrol_pump/petrol_pump.dart';
import 'package:frappe/frappe.dart';
import 'package:test/test.dart';
import 'package:optional/optional.dart';

void main() {
  group('Simple pump', () {
    setUpAll(() {
      initTransaction();
    });
    tearDown(() {
      assertCleanup();
    });

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

    test("test _whenLifted", () {
      EventStreamSink<UpDown> nozzle1StreamSink;
      EventStreamSink<UpDown> nozzle2StreamSink;
      EventStreamSink<UpDown> nozzle3StreamSink;
      ListenSubscription subscription;

      runTransaction(() {
        nozzle1StreamSink = EventStreamSink<UpDown>();
        nozzle2StreamSink = EventStreamSink<UpDown>();
        nozzle3StreamSink = EventStreamSink<UpDown>();

        final outputStream =
            _whenLifted(nozzle1StreamSink.stream, Fuel.one).orElses([
          _whenLifted(nozzle2StreamSink.stream, Fuel.two),
          _whenLifted(nozzle3StreamSink.stream, Fuel.three)
        ]);

        subscription = outputStream.listen((event) => print('output: $event'));
      });

      nozzle1StreamSink.send(UpDown.up);

      nozzle1StreamSink.send(UpDown.down);

      subscription.cancel();

      nozzle1StreamSink.close();
      nozzle2StreamSink.close();
      nozzle3StreamSink.close();
    });

    test("test startStream 01", () {
      EventStreamSink<UpDown> nozzle1StreamSink;
      ListenSubscription subscription;

      runTransaction(() {
        nozzle1StreamSink = EventStreamSink<UpDown>();

        final fillActiveStateRef = OptionalValueStateLink<Fuel>();

        final startStream = _whenLifted(nozzle1StreamSink.stream, Fuel.one)
            .snapshot<Optional<Fuel>, Optional<Fuel>>(
                fillActiveStateRef.state,
                (newFuel, fillActive) => !fillActive.isPresent
                    ? Optional.of(newFuel)
                    : Optional.empty())
            .asOptional<Fuel>()
            .mapWhereOptional();

        final endStream = _whenSetDown(
            nozzle1StreamSink.stream, Fuel.one, fillActiveStateRef.state);

        fillActiveStateRef.connect(endStream
            .mapToOptionalEmpty<Fuel>()
            .orElse(startStream.mapToOptionalOf())
            .toState(Optional.empty())
            .asOptional<Fuel>());

        subscription = nozzle1StreamSink.stream
            .listen((event) => print('nozzle1: $event'))
            .append(startStream.listen((event) => print('start: $event')))
            .append(fillActiveStateRef.state
                .listen((value) => print('fillActive: $value')))
            .append(endStream.listen((event) => print('end: $event')));
      });

      nozzle1StreamSink.send(UpDown.up);

      nozzle1StreamSink.send(UpDown.down);

      subscription.cancel();

      nozzle1StreamSink.close();
    });

    test("test startStream 02", () {
      EventStreamSink<UpDown> nozzle1StreamSink;
      ListenSubscription subscription;

      runTransaction(() {
        nozzle1StreamSink = EventStreamSink<UpDown>();

        final fillActiveStateRef = OptionalValueStateLink<Fuel>();

        final startStream = _whenLifted(nozzle1StreamSink.stream, Fuel.one)
            .orElse(EventStream<Fuel>.never())
            .snapshot<Optional<Fuel>, Optional<Fuel>>(
                fillActiveStateRef.state,
                (newFuel, fillActive) => !fillActive.isPresent
                    ? Optional.of(newFuel)
                    : Optional.empty())
            .asOptional<Fuel>()
            .mapWhereOptional();

        final endStream = _whenSetDown(
                nozzle1StreamSink.stream, Fuel.one, fillActiveStateRef.state)
            .orElse(EventStream<Unit>.never());

        fillActiveStateRef.connect(endStream
            .mapToOptionalEmpty<Fuel>()
            .orElse(startStream.mapToOptionalOf())
            .toState(Optional.empty())
            .asOptional<Fuel>());

        subscription = nozzle1StreamSink.stream
            .listen((event) => print('nozzle1: $event'))
            .append(startStream.listen((event) => print('start: $event')))
            .append(fillActiveStateRef.state
                .listen((value) => print('fillActive: $value')))
            .append(endStream.listen((event) => print('end: $event')));
      });

      nozzle1StreamSink.send(UpDown.up);

      nozzle1StreamSink.send(UpDown.down);

      subscription.cancel();

      nozzle1StreamSink.close();
    });

    test("test startStream 03", () {
      EventStreamSink<UpDown> nozzle1StreamSink;
      EventStreamSink<UpDown> nozzle2StreamSink;
      EventStreamSink<UpDown> nozzle3StreamSink;
      ListenSubscription subscription;

      runTransaction(() {
        nozzle1StreamSink = EventStreamSink<UpDown>();
        nozzle2StreamSink = EventStreamSink<UpDown>();
        nozzle3StreamSink = EventStreamSink<UpDown>();

        final fillActiveStateRef = OptionalValueStateLink<Fuel>();

        final startStream = _whenLifted(nozzle1StreamSink.stream, Fuel.one)
            .orElses([
              _whenLifted(nozzle2StreamSink.stream, Fuel.two),
              _whenLifted(nozzle3StreamSink.stream, Fuel.three)
            ])
            .snapshot<Optional<Fuel>, Optional<Fuel>>(
                fillActiveStateRef.state,
                (newFuel, fillActive) => !fillActive.isPresent
                    ? Optional.of(newFuel)
                    : Optional.empty())
            .asOptional<Fuel>()
            .mapWhereOptional();

        // final endStream = EventStream<Unit>.never();
        final endStream = _whenSetDown(
                nozzle1StreamSink.stream, Fuel.one, fillActiveStateRef.state)
            .orElses([
          _whenSetDown(
              nozzle2StreamSink.stream, Fuel.two, fillActiveStateRef.state),
          _whenSetDown(
              nozzle3StreamSink.stream, Fuel.three, fillActiveStateRef.state)
        ]);

        fillActiveStateRef.connect(endStream
            .mapToOptionalEmpty<Fuel>()
            .orElse(startStream.mapToOptionalOf())
            .toState(Optional.empty())
            .asOptional<Fuel>());

        subscription = nozzle1StreamSink.stream
            .listen((event) => print('nozzle1: $event'))
            .append(startStream.listen((event) => print('start: $event')))
            .append(fillActiveStateRef.state
                .listen((value) => print('fillActive: $value')))
            .append(endStream.listen((event) => print('end: $event')));
      });

      nozzle1StreamSink.send(UpDown.up);

      nozzle1StreamSink.send(UpDown.down);

      subscription.cancel();

      nozzle1StreamSink.close();
      nozzle2StreamSink.close();
      nozzle3StreamSink.close();
    });

    test("test 01", () {
      EventStreamSink<UpDown> nozzle1StreamSink;
      EventStreamSink<UpDown> nozzle2StreamSink;
      EventStreamSink<UpDown> nozzle3StreamSink;
      Lifecycle lifecycle;
      ListenSubscription subscription;

      runTransaction(() {
        nozzle1StreamSink = EventStreamSink<UpDown>();
        nozzle2StreamSink = EventStreamSink<UpDown>();
        nozzle3StreamSink = EventStreamSink<UpDown>();

        lifecycle = Lifecycle(
            nozzle1Stream: nozzle1StreamSink.stream,
            nozzle2Stream: nozzle2StreamSink.stream,
            nozzle3Stream: nozzle3StreamSink.stream);

        subscription = lifecycle.startStream
            .listen((event) => print('start: $event'))
            .append(lifecycle.endStream.listen((event) => print('end: $event')))
            .append(lifecycle.fillActiveState
                .listen((value) => print('fillActive: $value')));
      });

      nozzle1StreamSink.send(UpDown.up);

      nozzle1StreamSink.send(UpDown.down);

      subscription.cancel();

      nozzle1StreamSink.close();
      nozzle2StreamSink.close();
      nozzle3StreamSink.close();
    });
  });
}
