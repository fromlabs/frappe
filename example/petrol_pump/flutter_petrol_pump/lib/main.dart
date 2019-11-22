import 'package:flutter/material.dart';
import 'package:flutter_petrol_pump/page/petrol_pump.dart';
import 'package:frappe/frappe.dart';
import 'package:petrol_pump/petrol_pump.dart';
import 'package:provider/provider.dart';

void main() {
  initTransaction();

  runApp(PetrolPumpApp());
}

class PetrolPumpApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Provider<PetrolPumpBloc>(
        builder: (context) => PetrolPumpBlocImpl(),
        dispose: (context, bloc) => bloc.dispose(),
        child: MaterialApp(
          title: 'Petrol Pump',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: PetrolPumpPage(),
        ),
      );
}
