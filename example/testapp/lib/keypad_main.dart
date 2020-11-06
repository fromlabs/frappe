import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frappe/src/listen_subscription.dart';
import 'package:testapp/keypad/keypad_bloc.dart';
import 'package:testapp/value_state_builder.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'Flutter Demo Home Page'),
      );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required this.title}) : super();

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final KeypadBloc _keypadBloc;

  late final ListenSubscription _listener;

  @override
  void initState() {
    super.initState();

    _keypadBloc = KeypadBlocImpl();

    _listener = _keypadBloc.beepStream
        .listen((_) => SystemSound.play(SystemSoundType.click));
  }

  @override
  void dispose() {
    _listener.cancel();
    (_keypadBloc as KeypadBlocImpl).dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueStateBuilder<int>(
      state: _keypadBloc.valueState,
      builder: (context, keypadState) => Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
            ),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$keypadState',
                  style: Theme.of(context)!.textTheme.headline4,
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    children: List.generate(10, (index) {
                      return Center(
                        child: FlatButton(
                          child: Text(
                            '$index',
                            style: Theme.of(context)!.textTheme.headline5,
                          ),
                          onPressed: () => _keypadBloc.digit(index),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _keypadBloc.clear,
              tooltip: 'Clear',
              child: Icon(Icons.clear),
            ),
          ));
}
