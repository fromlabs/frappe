import 'package:frappe/frappe.dart';

EventStream<String?> search(EventStream<String> wordStream) {
  final definitionStreamSink = EventStreamSink<String?>();

  return definitionStreamSink.stream
      .addReferencedSubscription(wordStream.listen((word) async {
    await Future.delayed(Duration(seconds: 1));

    definitionStreamSink.send('Definition of $word');
  }));
}
