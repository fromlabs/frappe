import 'package:brew/brew.dart';
import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

class CounterBrew extends BaseBrew {
  late final ValueStateSink<int> _countSink;
  late final ValueState<int> count;

  @override
  void onBind() {
    _countSink = ValueStateSink(0);
    count = collect(_countSink.state);
  }

  void increment() {
    runTransaction(() {
      _countSink.send(count.getValue() + 1);
    });
  }
}

void main() {
  late FrappeScope scope;

  setUp(() {
    scope = FrappeScope();
  });

  tearDown(() {
    scope.dispose();
  });

  test('Brew onBind is called on construction', () {
    scope.run(() {
      late CounterBrew brew;
      runTransaction(() {
        brew = CounterBrew();
      });
      expect(brew.count.getValue(), equals(0));
      brew.dispose();
    });
  });

  test('Brew collect keeps reactive objects alive', () {
    scope.run(() {
      late CounterBrew brew;
      runTransaction(() {
        brew = CounterBrew();
      });
      brew.increment();
      expect(brew.count.getValue(), equals(1));
      brew.dispose();
    });
  });

  test('Brew dispose releases all collected references', () {
    scope.run(() {
      late CounterBrew brew;
      runTransaction(() {
        brew = CounterBrew();
      });
      brew.dispose();
    });
    scope.run(() => scope.assertCleanState());
  });
}
