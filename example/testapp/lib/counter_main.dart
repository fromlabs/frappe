import 'package:flutter/material.dart';
import 'package:testapp/core/view.dart';
import 'package:testapp/counter/counter_bloc.dart';
import 'package:testapp/core/value_state_builder.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Counter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocProvider<CounterBloc>(
        factory: () => CounterBloc(),
        builder: (context, snapshot) => MyHomePage(title: 'Counter Demo'),
      ));
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required this.title}) : super();

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) => BlocInject<CounterBloc>(
      builder: (context, counterBloc) => ValueStateBuilder<int>(
          state: counterBloc.valueState,
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
                  onPressed: counterBloc.increment,
                  tooltip: 'Increment',
                  child: Icon(Icons.add),
                ),
              )));
}
