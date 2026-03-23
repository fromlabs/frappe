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

  group('KeypadPump', () {
    test('preset LCD starts at 0', () {
      scope.run(() {
        runTransaction(() {
          final pump = KeypadPump();
          final outputs = pump.create(Inputs.defaults());
          final refs = FrappeReferenceCollector();
          _holdOutputs(outputs, refs);

          expect(outputs.presetLcdState.getValue(), '0');

          refs.dispose();
        });
      });
    });

    test('key presses update preset LCD', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late Outputs outputs;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          refs = FrappeReferenceCollector();
          keypadSink = refs.addStreamSink<NumericKey>();

          final pump = KeypadPump();
          outputs = pump.create(Inputs.defaults(
            keypadStream: keypadSink.stream,
          ));

          _holdOutputs(outputs, refs);
        });

        keypadSink.send(NumericKey.five);
        expect(outputs.presetLcdState.getValue(), '5');

        keypadSink.send(NumericKey.zero);
        expect(outputs.presetLcdState.getValue(), '50');

        refs.dispose();
      });
    });

    test('beep fires on key press', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late Outputs outputs;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          refs = FrappeReferenceCollector();
          keypadSink = refs.addStreamSink<NumericKey>();

          final pump = KeypadPump();
          outputs = pump.create(Inputs.defaults(
            keypadStream: keypadSink.stream,
          ));

          _holdOutputs(outputs, refs);
        });

        final beeps = <Unit>[];
        final beepSub = outputs.beepStream.listen(beeps.add);

        keypadSink.send(NumericKey.three);
        expect(beeps.length, 1);

        beepSub.cancel();
        refs.dispose();
      });
    });
  });
}
