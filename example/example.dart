import 'package:frappe/frappe.dart';

Future<void> main() async {
  // event stream sink
  final plusStreamSink = EventStreamSink<Unit>();
  final minusStreamSink = EventStreamSink<Unit>();

  // event stream
  final plusStream = plusStreamSink.stream;
  final minusStream = minusStreamSink.stream;

  // mapTo/map operator
  final incrementStream = plusStream.mapTo<int>(1);
  final decrementStream = minusStream.mapTo<int>(-1);

  // orElse/merge operator
  final deltaStream = incrementStream.orElse(decrementStream);

  // value state reference (for cyclic dependencies)
  final totalStateReference = ValueStateReference<int>();

  // value state
  final totalState = totalStateReference.state;

  // snapshot operator
  final totalUpdateStream = deltaStream.snapshot<int, int>(
      totalState, (delta, total) => total + delta);

  // event stream to value state conversion
  final updatedTotalState = totalUpdateStream.toState(0);

  // lazy reference link
  totalStateReference.link(updatedTotalState);

  // adding listeners
  final subscription = plusStream
      .listen((_) => print('+'))
      .append(minusStream.listen((_) => print('-')))
      .append(totalState.listen((total) => print('Updated total: $total')));

  print('Initial total: ${totalState.current}');

  plusStreamSink.send(unit);
  await delay;

  plusStreamSink.send(unit);
  await delay;

  plusStreamSink.send(unit);
  await delay;

  minusStreamSink.send(unit);
  await delay;

  minusStreamSink.send(unit);
  await delay;

  print('Final total: ${totalState.current}');

  // removing listeners
  await subscription.cancel();

  // check if all listeners are canceled
  assertEmptyBroadcastStreamSubscribers();
}

Future<void> get delay => Future(() {});
