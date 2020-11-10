import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frappe/src/listen_subscription.dart';
import 'package:testapp/core/bloc_state_builder.dart';
import 'package:testapp/core/view.dart';
import 'package:testapp/keypad/keypad_bloc.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Keypad Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: BlocProvider<KeypadBloc>(
            factory: () => KeypadBlocImpl(),
            builder: (context, snapshot) => MyHomePage(title: 'Keypad Demo')),
      );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required this.title}) : super();

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final ListenSubscription _listener;

  @override
  void initState() {
    super.initState();

    _listener = BlocProvider.of<KeypadBloc>(context)
        .beepStream
        .listen((_) => SystemSound.play(SystemSoundType.click));
  }

  @override
  void dispose() {
    _listener.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocInject<KeypadBloc>(
      builder: (context, keypadBloc) => BlocStateBuilder<int>(
          bloc: keypadBloc,
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
                        children: List.generate(
                            10,
                            (index) => Center(
                                  child: FlatButton(
                                    child: Text(
                                      '$index',
                                      style: Theme.of(context)!
                                          .textTheme
                                          .headline5,
                                    ),
                                    onPressed: () => keypadBloc.digit(index),
                                  ),
                                )),
                      ),
                    ),
                  ],
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: keypadBloc.clear,
                  tooltip: 'Clear',
                  child: Icon(Icons.clear),
                ),
              )));
}
