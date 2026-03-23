import 'package:frappe/frappe.dart';
import 'package:petrol_pump_brew/petrol_pump_brew.dart';
import 'package:test/test.dart';

void main() {
  late FrappeScope scope;

  setUp(() {
    scope = FrappeScope();
  });

  tearDown(() {
    scope.run(() => scope.assertCleanState());
    scope.dispose();
  });

  group('Lifecycle', () {
    test('initially no fuel is active', () {
      scope.run(() {
        runTransaction(() {
          final nozzle1 = EventStreamSink<UpDown>();
          final nozzle2 = EventStreamSink<UpDown>();
          final nozzle3 = EventStreamSink<UpDown>();

          final lifecycle = Lifecycle(
            nozzle1Stream: nozzle1.stream,
            nozzle2Stream: nozzle2.stream,
            nozzle3Stream: nozzle3.stream,
          );

          final ref = lifecycle.fillActiveState.toReference();
          expect(lifecycle.fillActiveState.getValue(), isNull);
          ref.dispose();
        });
      });
    });

    test('lifting nozzle 1 activates Fuel.one', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1;
        late EventStreamSink<UpDown> nozzle2;
        late EventStreamSink<UpDown> nozzle3;
        late Lifecycle lifecycle;
        late FrappeReference ref;

        runTransaction(() {
          nozzle1 = EventStreamSink<UpDown>();
          nozzle2 = EventStreamSink<UpDown>();
          nozzle3 = EventStreamSink<UpDown>();

          lifecycle = Lifecycle(
            nozzle1Stream: nozzle1.stream,
            nozzle2Stream: nozzle2.stream,
            nozzle3Stream: nozzle3.stream,
          );

          ref = lifecycle.fillActiveState.toReference();
        });

        nozzle1.send(UpDown.up);
        expect(lifecycle.fillActiveState.getValue(), Fuel.one);

        nozzle1.send(UpDown.down);
        expect(lifecycle.fillActiveState.getValue(), isNull);

        ref.dispose();
      });
    });

    test('lifting nozzle 2 activates Fuel.two', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1;
        late EventStreamSink<UpDown> nozzle2;
        late EventStreamSink<UpDown> nozzle3;
        late Lifecycle lifecycle;
        late FrappeReference ref;

        runTransaction(() {
          nozzle1 = EventStreamSink<UpDown>();
          nozzle2 = EventStreamSink<UpDown>();
          nozzle3 = EventStreamSink<UpDown>();

          lifecycle = Lifecycle(
            nozzle1Stream: nozzle1.stream,
            nozzle2Stream: nozzle2.stream,
            nozzle3Stream: nozzle3.stream,
          );

          ref = lifecycle.fillActiveState.toReference();
        });

        nozzle2.send(UpDown.up);
        expect(lifecycle.fillActiveState.getValue(), Fuel.two);

        nozzle2.send(UpDown.down);
        expect(lifecycle.fillActiveState.getValue(), isNull);

        ref.dispose();
      });
    });

    test('second nozzle is ignored while first is active', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1;
        late EventStreamSink<UpDown> nozzle2;
        late EventStreamSink<UpDown> nozzle3;
        late Lifecycle lifecycle;
        late FrappeReference ref;

        runTransaction(() {
          nozzle1 = EventStreamSink<UpDown>();
          nozzle2 = EventStreamSink<UpDown>();
          nozzle3 = EventStreamSink<UpDown>();

          lifecycle = Lifecycle(
            nozzle1Stream: nozzle1.stream,
            nozzle2Stream: nozzle2.stream,
            nozzle3Stream: nozzle3.stream,
          );

          ref = lifecycle.fillActiveState.toReference();
        });

        nozzle1.send(UpDown.up);
        expect(lifecycle.fillActiveState.getValue(), Fuel.one);

        // Second nozzle while first is active — ignored.
        nozzle2.send(UpDown.up);
        expect(lifecycle.fillActiveState.getValue(), Fuel.one);

        nozzle1.send(UpDown.down);
        expect(lifecycle.fillActiveState.getValue(), isNull);

        ref.dispose();
      });
    });

    test('start and end streams fire correctly', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1;
        late EventStreamSink<UpDown> nozzle2;
        late EventStreamSink<UpDown> nozzle3;
        late Lifecycle lifecycle;
        late FrappeReference ref;

        runTransaction(() {
          nozzle1 = EventStreamSink<UpDown>();
          nozzle2 = EventStreamSink<UpDown>();
          nozzle3 = EventStreamSink<UpDown>();

          lifecycle = Lifecycle(
            nozzle1Stream: nozzle1.stream,
            nozzle2Stream: nozzle2.stream,
            nozzle3Stream: nozzle3.stream,
          );

          ref = lifecycle.fillActiveState.toReference();
        });

        final starts = <Fuel>[];
        final ends = <Unit>[];
        final startSub = lifecycle.startStream.listen(starts.add);
        final endSub = lifecycle.endStream.listen(ends.add);

        nozzle1.send(UpDown.up);
        expect(starts, [Fuel.one]);
        expect(ends, isEmpty);

        nozzle1.send(UpDown.down);
        expect(starts, [Fuel.one]);
        expect(ends, [unit]);

        startSub.cancel();
        endSub.cancel();
        ref.dispose();
      });
    });
  });
}
