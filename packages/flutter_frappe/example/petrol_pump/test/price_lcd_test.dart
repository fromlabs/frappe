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

  group('priceLcd', () {
    test('shows idle price when no fuel is active', () {
      scope.run(() {
        runTransaction(() {
          final ValueState<Fuel?> fillActiveState = ValueState.constant(null);
          final priceState = ValueState.constant(0.0);

          final inputs = Inputs.defaults(
            price1State: ValueState.constant(2.149),
            price2State: ValueState.constant(2.341),
            price3State: ValueState.constant(1.499),
          );

          final lcd =
              priceLcd(fillActiveState, priceState, Fuel.one, inputs);
          final ref = lcd.toReference();

          expect(lcd.getValue(), '2.149');

          ref.dispose();
        });
      });
    });

    test('shows active price when matching fuel is flowing', () {
      scope.run(() {
        runTransaction(() {
          final ValueState<Fuel?> fillActiveState =
              ValueState.constant(Fuel.two);
          final priceState = ValueState.constant(3.5);

          final inputs = Inputs.defaults(
            price2State: ValueState.constant(2.341),
          );

          final lcd =
              priceLcd(fillActiveState, priceState, Fuel.two, inputs);
          final ref = lcd.toReference();

          expect(lcd.getValue(), '3.5');

          ref.dispose();
        });
      });
    });

    test('shows blank when a different fuel is active', () {
      scope.run(() {
        runTransaction(() {
          final ValueState<Fuel?> fillActiveState =
              ValueState.constant(Fuel.one);
          final priceState = ValueState.constant(2.0);

          final inputs = Inputs.defaults(
            price2State: ValueState.constant(2.341),
          );

          // Fuel.two LCD when Fuel.one is active — should be blank.
          final lcd =
              priceLcd(fillActiveState, priceState, Fuel.two, inputs);
          final ref = lcd.toReference();

          expect(lcd.getValue(), '');

          ref.dispose();
        });
      });
    });

    test('updates when fill active changes', () {
      scope.run(() {
        late ValueStateSink<Fuel?> fillActiveSink;
        late ValueState<String> lcd;
        final refs = FrappeReferenceCollector();

        runTransaction(() {
          fillActiveSink = refs.addStateSink<Fuel?>(null);
          final priceState = ValueState.constant(5.0);

          final inputs = Inputs.defaults(
            price1State: ValueState.constant(2.149),
          );

          lcd = priceLcd(
              fillActiveSink.state, priceState, Fuel.one, inputs);
          refs.add(lcd);
        });

        // No fuel active — shows idle price.
        expect(lcd.getValue(), '2.149');

        // Fuel.one becomes active — shows fill price.
        fillActiveSink.send(Fuel.one);
        expect(lcd.getValue(), '5.0');

        // Different fuel becomes active — blank.
        fillActiveSink.send(Fuel.two);
        expect(lcd.getValue(), '');

        // Back to idle.
        fillActiveSink.send(null);
        expect(lcd.getValue(), '2.149');

        refs.dispose();
      });
    });
  });
}
