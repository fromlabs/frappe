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

  group('Keypad', () {
    test('starts at zero', () {
      scope.run(() {
        runTransaction(() {
          final keypadSink = EventStreamSink<NumericKey>();

          final keypad = Keypad(
            keypadStream: keypadSink.stream,
            clearStream: EventStream.never(),
            activeState: ValueState.constant(true),
          );

          final ref = keypad.valueState.toReference();
          expect(keypad.valueState.getValue(), 0);
          ref.dispose();
        });
      });
    });

    test('accumulates digit keys', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late Keypad keypad;
        final refs = FrappeReferenceCollector();

        runTransaction(() {
          keypadSink = refs.addStreamSink<NumericKey>();

          keypad = Keypad(
            keypadStream: keypadSink.stream,
            clearStream: EventStream.never(),
            activeState: ValueState.constant(true),
          );

          keypad.hold(refs);
        });

        keypadSink.send(NumericKey.one);
        expect(keypad.valueState.getValue(), 1);

        keypadSink.send(NumericKey.two);
        expect(keypad.valueState.getValue(), 12);

        keypadSink.send(NumericKey.three);
        expect(keypad.valueState.getValue(), 123);

        refs.dispose();
      });
    });

    test('clear key resets to zero', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late Keypad keypad;
        final refs = FrappeReferenceCollector();

        runTransaction(() {
          keypadSink = refs.addStreamSink<NumericKey>();

          keypad = Keypad(
            keypadStream: keypadSink.stream,
            clearStream: EventStream.never(),
            activeState: ValueState.constant(true),
          );

          keypad.hold(refs);
        });

        keypadSink.send(NumericKey.five);
        expect(keypad.valueState.getValue(), 5);

        keypadSink.send(NumericKey.clear);
        expect(keypad.valueState.getValue(), 0);

        refs.dispose();
      });
    });

    test('ignores keys over 1000', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late Keypad keypad;
        final refs = FrappeReferenceCollector();

        runTransaction(() {
          keypadSink = refs.addStreamSink<NumericKey>();

          keypad = Keypad(
            keypadStream: keypadSink.stream,
            clearStream: EventStream.never(),
            activeState: ValueState.constant(true),
          );

          keypad.hold(refs);
        });

        keypadSink.send(NumericKey.nine);
        keypadSink.send(NumericKey.nine);
        keypadSink.send(NumericKey.nine);
        expect(keypad.valueState.getValue(), 999);

        keypadSink.send(NumericKey.one);
        expect(keypad.valueState.getValue(), 999);

        refs.dispose();
      });
    });

    test('ignores keys when inactive', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late Keypad keypad;
        final refs = FrappeReferenceCollector();

        runTransaction(() {
          keypadSink = refs.addStreamSink<NumericKey>();

          keypad = Keypad(
            keypadStream: keypadSink.stream,
            clearStream: EventStream.never(),
            activeState: ValueState.constant(false),
          );

          keypad.hold(refs);
        });

        keypadSink.send(NumericKey.five);
        expect(keypad.valueState.getValue(), 0);

        refs.dispose();
      });
    });

    test('clear stream resets value', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late EventStreamSink<Unit> clearSink;
        late Keypad keypad;
        final refs = FrappeReferenceCollector();

        runTransaction(() {
          keypadSink = refs.addStreamSink<NumericKey>();
          clearSink = refs.addStreamSink<Unit>();

          keypad = Keypad(
            keypadStream: keypadSink.stream,
            clearStream: clearSink.stream,
            activeState: ValueState.constant(true),
          );

          keypad.hold(refs);
        });

        keypadSink.send(NumericKey.seven);
        expect(keypad.valueState.getValue(), 7);

        clearSink.send(unit);
        expect(keypad.valueState.getValue(), 0);

        refs.dispose();
      });
    });

    test('beeps on valid key press', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late Keypad keypad;
        final refs = FrappeReferenceCollector();

        runTransaction(() {
          keypadSink = refs.addStreamSink<NumericKey>();

          keypad = Keypad(
            keypadStream: keypadSink.stream,
            clearStream: EventStream.never(),
            activeState: ValueState.constant(true),
          );

          keypad.hold(refs);
        });

        final beeps = <Unit>[];
        final beepSub = keypad.beepStream.listen(beeps.add);

        keypadSink.send(NumericKey.one);
        expect(beeps.length, 1);

        keypadSink.send(NumericKey.two);
        expect(beeps.length, 2);

        beepSub.cancel();
        refs.dispose();
      });
    });

    test('zero key works correctly', () {
      scope.run(() {
        late EventStreamSink<NumericKey> keypadSink;
        late Keypad keypad;
        final refs = FrappeReferenceCollector();

        runTransaction(() {
          keypadSink = refs.addStreamSink<NumericKey>();

          keypad = Keypad(
            keypadStream: keypadSink.stream,
            clearStream: EventStream.never(),
            activeState: ValueState.constant(true),
          );

          keypad.hold(refs);
        });

        keypadSink.send(NumericKey.one);
        keypadSink.send(NumericKey.zero);
        expect(keypad.valueState.getValue(), 10);

        refs.dispose();
      });
    });
  });
}
