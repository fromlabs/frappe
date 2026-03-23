import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frappe/frappe.dart';
import 'package:flutter_frappe/flutter_frappe.dart';

void main() {
  late FrappeScope scope;

  setUp(() {
    scope = FrappeScope();
  });

  tearDown(() {
    scope.run(() => scope.assertCleanState());
    scope.dispose();
  });

  group('Observe', () {
    testWidgets('renders the initial value from getValue()', (tester) async {
      await scope.run(() async {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: sink.state,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);

        // Dispose after removing the widget to cancel the subscription.
        await tester.pumpWidget(const SizedBox());
        ref.dispose();
      });
    });

    testWidgets('rebuilds when the state value changes', (tester) async {
      await scope.run(() async {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: sink.state,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);

        sink.send(42);
        await tester.pump();

        expect(find.text('42'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        ref.dispose();
      });
    });

    testWidgets('rebuilds on each subsequent value change', (tester) async {
      await scope.run(() async {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: sink.state,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        for (var i = 1; i <= 3; i++) {
          sink.send(i);
          await tester.pump();
          expect(find.text('$i'), findsOneWidget);
        }

        await tester.pumpWidget(const SizedBox());
        ref.dispose();
      });
    });

    testWidgets('resubscribes when the state instance changes',
        (tester) async {
      await scope.run(() async {
        late ValueStateSink<int> sinkA;
        late ValueStateSink<int> sinkB;
        late FrappeReference<ValueState<int>> refA;
        late FrappeReference<ValueState<int>> refB;

        runTransaction(() {
          sinkA = ValueStateSink<int>(10);
          sinkB = ValueStateSink<int>(20);
          refA = sinkA.state.toReference();
          refB = sinkB.state.toReference();
        });

        // Pump with state A.
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: sinkA.state,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        expect(find.text('10'), findsOneWidget);

        // Switch to state B — should show B's current value.
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: sinkB.state,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        expect(find.text('20'), findsOneWidget);

        // Sending to B should update the widget.
        sinkB.send(25);
        await tester.pump();
        expect(find.text('25'), findsOneWidget);

        // Sending to A should NOT update the widget (unsubscribed).
        sinkA.send(99);
        await tester.pump();
        expect(find.text('25'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        refA.dispose();
        refB.dispose();
      });
    });

    testWidgets('does not resubscribe when the same state instance is provided',
        (tester) async {
      await scope.run(() async {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        Widget buildWidget({required String label}) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: sink.state,
              // Use a different builder closure to trigger didUpdateWidget,
              // but keep the same state instance.
              builder: (context, value) => Text('$label:$value'),
            ),
          );
        }

        await tester.pumpWidget(buildWidget(label: 'A'));
        expect(find.text('A:0'), findsOneWidget);

        // Rebuild with same state but different builder — should keep value.
        sink.send(5);
        await tester.pump();
        await tester.pumpWidget(buildWidget(label: 'B'));
        expect(find.text('B:5'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        ref.dispose();
      });
    });

    testWidgets('stops receiving updates after dispose', (tester) async {
      await scope.run(() async {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: sink.state,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);

        // Remove the widget (triggers dispose and subscription cancel).
        await tester.pumpWidget(const SizedBox());

        // Sending after dispose should not cause errors.
        sink.send(99);
        await tester.pump();

        // The old text is gone — widget is disposed.
        expect(find.text('0'), findsNothing);
        expect(find.text('99'), findsNothing);

        ref.dispose();
      });
    });

    testWidgets('works with ValueState.constant', (tester) async {
      await scope.run(() async {
        final state = runTransaction(() => ValueState.constant(42));

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: state,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        expect(find.text('42'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      });
    });

    testWidgets('passes BuildContext to builder', (tester) async {
      await scope.run(() async {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        BuildContext? capturedContext;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Observe<int>(
              state: sink.state,
              builder: (context, value) {
                capturedContext = context;
                return Text('$value');
              },
            ),
          ),
        );

        expect(capturedContext, isNotNull);

        await tester.pumpWidget(const SizedBox());
        ref.dispose();
      });
    });
  });
}
