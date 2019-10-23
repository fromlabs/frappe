import 'package:frappe/frappe.dart';
import 'package:frappe/src/broadcast_stream.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    assertEmptyBroadcastStreamSubscribers();
  });

  group('ValueState', () {
    test('ValueState.constant', () {
      final k1 = ValueState.constant(10);

      expect(k1.current(), equals(10));

      final k2 = k1.map((n) => n * 2);

      expect(k2.current(), equals(20));
    });
  });

  group('ValueStateSink', () {
    test('ValueStateSink', () {
      final sink1 = ValueStateSink(10);

      expect(sink1.state.current(), equals(10));

      final s2 = sink1.state.map((n) => n * 2);

      expect(s2.current(), equals(20));

      sink1.send(20);

      expect(sink1.state.current(), equals(20));
      expect(s2.current(), equals(40));
    });
  });
}
