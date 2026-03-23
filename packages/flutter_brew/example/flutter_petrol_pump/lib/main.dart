import 'package:flutter/material.dart';
import 'package:flutter_brew/flutter_brew.dart';
import 'package:petrol_pump_brew/petrol_pump_brew.dart';

import 'src/page/petrol_pump_page.dart';

void main() => runApp(const PetrolPumpApp());

/// Root widget — provides [DefaultPetrolPumpBrew] to the widget tree.
///
/// The concrete [DefaultPetrolPumpBrew] is registered with [BrewProvider]
/// for lifecycle management. UI widgets consume the [PetrolPumpBrew]
/// interface for a clean, encapsulated API.
class PetrolPumpApp extends StatelessWidget {
  const PetrolPumpApp({super.key});

  @override
  Widget build(BuildContext context) => BrewProvider<PetrolPumpBrew>(
        create: () => DefaultPetrolPumpBrew(),
        child: MaterialApp(
          title: 'Petrol Pump',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: const PetrolPumpPage(),
        ),
      );
}
