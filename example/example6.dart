import 'package:frappe/frappe.dart';

void main() {
  late final FrappeReference<EventStream<int>> streamReference;

  late final EventStreamSink<int> inputSink;

  runTransaction(() {
    inputSink = EventStreamSink<int>();

    final outputSink = EventStreamSink<int>();

    final subscription = inputSink.stream.listen((value) {
      print('value: $value');
    });

    streamReference = outputSink.stream
        .addListenSubscriptionCleaner(subscription)
        .toReference();
  });

  inputSink.send(1);

  streamReference.dispose();

  // assert that all references are disposed
  FrappeObject.assertCleanState();
}
