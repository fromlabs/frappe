import 'package:frappe/frappe.dart';
import 'package:petrol_pump/petrol_pump.dart';
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

  group('LifecyclePump', () {
    test('delivery is off initially', () {
      scope.run(() {
        runTransaction(() {
          final pump = LifecyclePump();
          final outputs = pump.create(Inputs.defaults());
          final refs = FrappeReferenceCollector();
          refs.add(outputs.deliveryState);
          refs.add(outputs.saleCostLcdState);

          expect(outputs.deliveryState.getValue(), Delivery.off);
          expect(outputs.saleCostLcdState.getValue(), '');

          refs.dispose();
        });
      });
    });

    test('lifting nozzle 1 activates fast1 delivery', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1Sink;
        late Outputs outputs;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          nozzle1Sink = EventStreamSink<UpDown>();

          refs = FrappeReferenceCollector();
          refs.add(nozzle1Sink.stream);

          final pump = LifecyclePump();
          outputs = pump.create(Inputs.defaults(
            nozzle1Stream: nozzle1Sink.stream,
          ));

          refs.add(outputs.deliveryState);
          refs.add(outputs.saleCostLcdState);
        });

        nozzle1Sink.send(UpDown.up);
        expect(outputs.deliveryState.getValue(), Delivery.fast1);
        expect(outputs.saleCostLcdState.getValue(), '1');

        nozzle1Sink.send(UpDown.down);
        expect(outputs.deliveryState.getValue(), Delivery.off);
        expect(outputs.saleCostLcdState.getValue(), '');

        refs.dispose();
      });
    });

    test('lifting nozzle 2 activates fast2 delivery', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle2Sink;
        late Outputs outputs;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          nozzle2Sink = EventStreamSink<UpDown>();

          refs = FrappeReferenceCollector();
          refs.add(nozzle2Sink.stream);

          final pump = LifecyclePump();
          outputs = pump.create(Inputs.defaults(
            nozzle2Stream: nozzle2Sink.stream,
          ));

          refs.add(outputs.deliveryState);
          refs.add(outputs.saleCostLcdState);
        });

        nozzle2Sink.send(UpDown.up);
        expect(outputs.deliveryState.getValue(), Delivery.fast2);
        expect(outputs.saleCostLcdState.getValue(), '2');

        nozzle2Sink.send(UpDown.down);
        refs.dispose();
      });
    });

    test('lifting nozzle 3 activates fast3 delivery', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle3Sink;
        late Outputs outputs;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          nozzle3Sink = EventStreamSink<UpDown>();

          refs = FrappeReferenceCollector();
          refs.add(nozzle3Sink.stream);

          final pump = LifecyclePump();
          outputs = pump.create(Inputs.defaults(
            nozzle3Stream: nozzle3Sink.stream,
          ));

          refs.add(outputs.deliveryState);
          refs.add(outputs.saleCostLcdState);
        });

        nozzle3Sink.send(UpDown.up);
        expect(outputs.deliveryState.getValue(), Delivery.fast3);
        expect(outputs.saleCostLcdState.getValue(), '3');

        nozzle3Sink.send(UpDown.down);
        refs.dispose();
      });
    });
  });
}
