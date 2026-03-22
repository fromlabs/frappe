// Counter FRP example.
//
// Demonstrates: sink, stream, mapTo, orElse, snapshot, ValueStateLink,
// listen, FrappeReference, ListenSubscription lifecycle.
import 'package:frappe/frappe.dart';

void main() {
  final scope = ReactiveScope();

  scope.run(() {
    late final EventStreamSink<Unit> plusStreamSink;
    late final EventStreamSink<Unit> minusStreamSink;
    late final FrappeReference<ValueState<int>> totalStateReference;
    late final ListenSubscription subscription;

    scope.runTransaction(() {
      plusStreamSink = EventStreamSink<Unit>();
      minusStreamSink = EventStreamSink<Unit>();

      final plusStream = plusStreamSink.stream;
      final minusStream = minusStreamSink.stream;

      final incrementStream = plusStream.mapTo<int>(1);
      final decrementStream = minusStream.mapTo<int>(-1);

      final deltaStream = incrementStream.orElse(decrementStream);

      // ValueStateLink for cyclic dependency
      final totalStateLink = ValueStateLink<int>();
      final totalState = totalStateLink.state;

      totalStateReference = totalState.toReference();

      final totalUpdateStream = deltaStream.snapshot<int, int>(
          totalState, (delta, total) => total + delta);

      final updatedTotalState = totalUpdateStream.toState(0);
      totalStateLink.connect(updatedTotalState);

      subscription = plusStream
          .listen((_) => print('+'))
          .append(minusStream.listen((_) => print('-')))
          .append(totalState.listen((total) => print('Updated total: $total')));
    });

    print('Initial total: ${totalStateReference.object.getValue()}');

    plusStreamSink.send(unit);
    plusStreamSink.send(unit);
    plusStreamSink.send(unit);
    minusStreamSink.send(unit);
    minusStreamSink.send(unit);

    print('Final total: ${totalStateReference.object.getValue()}');

    subscription.cancel();
    totalStateReference.dispose();

    scope.assertCleanState();
  });

  scope.dispose();
}
