import 'package:frappe/frappe.dart';

void main() {
  // event stream sink
  late final EventStreamSink<Unit> plusStreamSink;
  late final EventStreamSink<Unit> minusStreamSink;

  late final FrappeReference<ValueState<int>> totalStateReference;
  late final ListenSubscription subscription;

  runTransaction(() {
    // event stream sink
    plusStreamSink = EventStreamSink<Unit>();
    minusStreamSink = EventStreamSink<Unit>();

    // event stream
    final plusStream = plusStreamSink.stream;
    final minusStream = minusStreamSink.stream;

    // mapTo/map operator
    final incrementStream = plusStream.mapTo<int>(1);
    final decrementStream = minusStream.mapTo<int>(-1);

    // orElse/merge operator
    final deltaStream = incrementStream.orElse(decrementStream);

    // value state link (for cyclic dependencies)
    final totalStateLink = ValueStateLink<int>();

    // value state
    final totalState = totalStateLink.state;

    // hold reference to state
    totalStateReference = totalState.toReference();

    // snapshot operator
    final totalUpdateStream = deltaStream.snapshot<int, int>(
        totalState, (delta, total) => total + delta);

    // event stream to value state conversion
    final updatedTotalState = totalUpdateStream.toState(0);

    // lazy state link connection
    totalStateLink.connect(updatedTotalState);

    // adding listeners
    subscription = plusStream
        .listen((_) => print('+'))
        .append(minusStream.listen((_) => print('-')))
        .append(totalState.listen((total) => print('Updated total: $total')));
  });

  print('Initial total: ${totalStateReference.object.getValue()}');

  plusStreamSink.send(unit); // +

  plusStreamSink.send(unit); // +

  plusStreamSink.send(unit); // +

  minusStreamSink.send(unit); // -

  minusStreamSink.send(unit); // -

  print('Final total: ${totalStateReference.object.getValue()}');

  // removing listeners
  subscription.cancel();

  // dispose reference to state
  totalStateReference.dispose();

  // assert that all listeners are canceled
  FrappeObject.assertCleanState();
}
