import 'package:frappe/frappe.dart';
import 'package:testapp/lookup/lookup_io.dart';

// functional logic unit

class LookupFlutOutput {
  final EventStream<String?> definitionStream;

  LookupFlutOutput({required this.definitionStream});
}

LookupFlutOutput lookupFlut({
  required EventStream<String> wordStream,
  required LookupIo lookupIo,
}) {
  final definitionStreamSink = EventStreamSink<String?>();

  wordStream.listen((word) async {
    try {
      final definition = await lookupIo.call(word);

      definitionStreamSink.send(definition);
    } catch (e) {
      print(e);

      definitionStreamSink.sendNull();
    }
  }, createReference: false);

  return LookupFlutOutput(
      definitionStream: definitionStreamSink.stream.linkObject(wordStream));
}
