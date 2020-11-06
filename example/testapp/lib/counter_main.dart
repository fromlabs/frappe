import 'package:flutter/material.dart';
import 'package:testapp/counter_bloc.dart';
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
  late final CounterBloc _counterBloc;

  @override
  void initState() {
    super.initState();

    _counterBloc = CounterBloc();
  }

  @override
  void dispose() {
    _counterBloc.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueStateBuilder<int>(
      state: _counterBloc.valueState,
      builder: (context, counterState) => Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'You have pushed the button this many times:',
                  ),
                  Text(
                    '$counterState',
                    style: Theme.of(context)!.textTheme.headline4,
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _counterBloc.increment,
              tooltip: 'Increment',
              child: Icon(Icons.add),
            ),
          ));
}
