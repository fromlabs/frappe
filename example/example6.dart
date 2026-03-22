// addListenSubscriptionCleaner example.
//
// Demonstrates how to tie a ListenSubscription's lifetime to a stream's
// reference count. When the stream's FrappeReference is disposed,
// the attached subscription is automatically cancelled.
import 'package:frappe/frappe.dart';

void main() {
  final scope = ReactiveScope();

  scope.run(() {
    late final FrappeReference<EventStream<int>> streamReference;
    late final EventStreamSink<int> inputSink;

    scope.runTransaction(() {
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

    // Disposing the stream reference also cancels the attached subscription
    streamReference.dispose();

    scope.assertCleanState();
  });

  scope.dispose();
}
