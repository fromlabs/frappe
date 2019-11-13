import 'dart:async';

import 'package:petrol_pump/petrol_pump.dart';
import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

void main() {
  group('Simple pump', () {
    setUpAll(() {
      initTransaction();
    });
    tearDown(() {
      assertCleanup();
    });

    test("test 01", () {
      EventStreamSink<UpDown> nozzle1StreamSink;
      EventStreamSink<UpDown> nozzle2StreamSink;
      EventStreamSink<UpDown> nozzle3StreamSink;
      Lifecycle lifecycle;
      ListenSubscription subscription;

      runTransaction(() {
        nozzle1StreamSink = EventStreamSink<UpDown>();
        nozzle2StreamSink = EventStreamSink<UpDown>();
        nozzle3StreamSink = EventStreamSink<UpDown>();

        lifecycle = Lifecycle(
            nozzle1Stream: nozzle1StreamSink.stream,
            nozzle2Stream: nozzle2StreamSink.stream,
            nozzle3Stream: nozzle3StreamSink.stream);

        subscription = lifecycle.startStream
            .listen((event) => print('start: $event'))
            .append(lifecycle.endStream.listen((event) => print('end: $event')))
            .append(lifecycle.fillActiveState
                .listen((value) => print('fillActive: $value')));
      });

      nozzle1StreamSink.send(UpDown.up);

      subscription.cancel();

      nozzle1StreamSink.close();
      nozzle2StreamSink.close();
      nozzle3StreamSink.close();
    });
  });
}
