import 'package:flutter/material.dart';
import 'package:testapp/core/value_state_builder.dart';
import 'package:testapp/core/view.dart';
import 'package:testapp/lookup/lookup_bloc.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lookup Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: BlocProvider<LookupBloc>(
            factory: () => LookupBlocImpl(),
            builder: (context, snapshot) {
              return MyHomePage(title: 'Lookup Demo');
            }),
      );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required this.title}) : super();

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
        text: BlocProvider.of<LookupBloc>(context)
            .lookupState
            .getValue()
            .definition);
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocInject<LookupBloc>(
      builder: (context, lookupBloc) => ValueStateBuilder<LookupData>(
          state: lookupBloc.lookupState,
          builder: (context, lookupData) => Scaffold(
                appBar: AppBar(
                  title: Text(widget.title),
                ),
                body: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _controller,
                      onSubmitted: lookupBloc.lookup,
                      enabled: !lookupData.isLoading,
                    ),
                    Expanded(
                      child: Text(
                        lookupData.isLoading
                            ? 'Lookup...'
                            : lookupData.definition,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )));
}
