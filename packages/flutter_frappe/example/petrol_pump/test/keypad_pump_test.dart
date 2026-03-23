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

  group('KeypadPump', () {
    test('preset LCD starts at 0', () {
      scope.run(() {
        runTransaction(() {
          final pump = KeypadPump();
          final outputs = pump.create(Inputs.defaults());
          final refs = FrappeReferenceCollector();
          refs.add(outputs.presetLcdState);
          refs.add(outputs.beepStream);

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
          keypadSink = EventStreamSink<NumericKey>();

          refs = FrappeReferenceCollector();
          refs.add(keypadSink.stream);

          final pump = KeypadPump();
          outputs = pump.create(Inputs.defaults(
            keypadStream: keypadSink.stream,
          ));

          refs.add(outputs.presetLcdState);
          refs.add(outputs.beepStream);
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
          keypadSink = EventStreamSink<NumericKey>();

          refs = FrappeReferenceCollector();
          refs.add(keypadSink.stream);

          final pump = KeypadPump();
          outputs = pump.create(Inputs.defaults(
            keypadStream: keypadSink.stream,
          ));

          refs.add(outputs.presetLcdState);
          refs.add(outputs.beepStream);
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
