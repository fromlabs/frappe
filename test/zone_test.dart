import 'dart:async';

log() => print(Zone.current['TX']);

main() async {
  log();

  runZoned(() {
    log();

    callback(log);

    print('end transaziont');
  }, zoneValues: {
    'TX': 'TX1',
  });

  print('end');

  await Future.delayed(Duration(seconds: 1));
}

callback(f) async {
  f();

  log();

  await log();

  await Future(() {});

  print('fine');

  log();
}
