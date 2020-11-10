import 'package:frappe/frappe.dart';
import 'package:testapp/core/frappe_bloc.dart';
import 'package:testapp/lookup/busy_flut.dart';
import 'package:testapp/lookup/lookup_flut.dart';
import 'package:testapp/lookup/lookup_io.dart';

// business logic component
class LookupData {
  final bool isLoading;
  final String word;
  final String definition;

  LookupData({
    required this.isLoading,
    required this.word,
    required this.definition,
  });
}

abstract class LookupBloc implements Bloc<LookupData> {
  // commands
  void lookup(String word);
}

class LookupBlocImpl extends BaseBloc<LookupData> implements LookupBloc {
  late final EventStreamSink<String> _lookupSink;

  @override
  ValueState<LookupData> create() {
    _lookupSink = EventStreamSink<String>();

    final _isBusyFlutOutput = isBusyFlut<String, String?>(
        inputStream: _lookupSink.stream,
        action: (inputStream) =>
            lookupFlut(wordStream: inputStream, lookupIo: testLookupIo)
                .definitionStream);

    return _lookupSink.stream.toState('').combine2<bool, String, LookupData>(
          _isBusyFlutOutput.isBusyState,
          _isBusyFlutOutput.outputStream
              .map<String>((definition) => definition ?? '')
              .toState(''),
          (word, isBusy, definition) => LookupData(
            isLoading: isBusy,
            word: word,
            definition: definition,
          ),
        );
  }

  // commands
  @override
  void lookup(String word) => _lookupSink.send(word);
}
