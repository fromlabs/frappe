import 'package:frappe/frappe.dart';

void main() {
  late final FrappeReference<EventStream<int>> streamReference;

  late final EventStreamSink<int> inputSink;

  runTransaction(() {
    inputSink = EventStreamSink<int>();

    final outputSink = EventStreamSink<int>();

    streamReference = outputSink.stream
        .addReferencedSubscription(inputSink.stream.listen((value) {
      print('value: $value');
    })).toReference();
  });

  streamReference.dispose();

  // assert that all references are disposed
  FrappeObject.assertCleanState();
}
