import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provider/sensor_provider.dart';
import 'screens/sensor_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => SensorProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Sensor Reading', home: SensorScreen());
  }
}
