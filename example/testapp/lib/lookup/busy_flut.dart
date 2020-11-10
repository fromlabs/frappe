import 'package:frappe/frappe.dart';

// functional logic unit

class BusyFlutOutput<E> {
  final EventStream<E> outputStream;
  final ValueState<bool> isBusyState;

  BusyFlutOutput({
    required this.outputStream,
    required this.isBusyState,
  });
}

BusyFlutOutput isBusyFlut<E, ER>({
  required EventStream<E> inputStream,
  required EventStream<ER> Function(EventStream<E>) action,
}) {
  final outputStream = action(inputStream);

  return BusyFlutOutput(
      outputStream: outputStream,
      isBusyState: inputStream
          .mapTo(true)
          .orElse(outputStream.mapTo(false))
          .toState(false));
}
