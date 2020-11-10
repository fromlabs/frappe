typedef LookupIo = Future<String?> Function(String);

Future<String?> testLookupIo(String word) async {
  await Future.delayed(Duration(seconds: 1));

  return 'Definition of $word';
}
