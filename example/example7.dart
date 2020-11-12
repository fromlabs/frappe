import 'package:frappe/frappe.dart';

void main() {
  late final FrappeReference<EventStream<int>> streamReference;

  late final EventStreamSink<int> inputSink;

  runTransaction(() {
    inputSink = EventStreamSink<int>();

    final outputSink = EventStreamSink<int>();

    inputSink.stream.listen((value) {
      print('value: $value');

      outputSink.send(value);
    }, createReference: false);

    streamReference =
        outputSink.stream.linkEventStream(inputSink.stream).toReference();
  });

  inputSink.send(1);

  streamReference.dispose();

  // assert that all references are disposed
  FrappeObject.assertCleanState();
}
