import 'package:frappe/frappe.dart';
import 'package:petrol_pump_brew/petrol_pump_brew.dart';
import 'package:test/test.dart';

/// References all output fields via [refs] to keep them alive.
void _holdOutputs(Outputs outputs, FrappeReferenceCollector refs) {
  refs
    ..add(outputs.deliveryState)
    ..add(outputs.presetLcdState)
    ..add(outputs.saleCostLcdState)
    ..add(outputs.saleQuantityLcdState)
    ..add(outputs.priceLcd1State)
    ..add(outputs.priceLcd2State)
    ..add(outputs.priceLcd3State)
    ..add(outputs.beepStream)
    ..add(outputs.saleCompleteStream);
}

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
          _holdOutputs(outputs, refs);

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
          refs = FrappeReferenceCollector();
          nozzle1Sink = refs.addStreamSink<UpDown>();

          final pump = LifecyclePump();
          outputs = pump.create(Inputs.defaults(
            nozzle1Stream: nozzle1Sink.stream,
          ));

          _holdOutputs(outputs, refs);
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
          refs = FrappeReferenceCollector();
          nozzle2Sink = refs.addStreamSink<UpDown>();

          final pump = LifecyclePump();
          outputs = pump.create(Inputs.defaults(
            nozzle2Stream: nozzle2Sink.stream,
          ));

          _holdOutputs(outputs, refs);
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
          refs = FrappeReferenceCollector();
          nozzle3Sink = refs.addStreamSink<UpDown>();

          final pump = LifecyclePump();
          outputs = pump.create(Inputs.defaults(
            nozzle3Stream: nozzle3Sink.stream,
          ));

          _holdOutputs(outputs, refs);
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
