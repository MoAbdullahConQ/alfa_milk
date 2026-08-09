import 'package:flutter/material.dart';

import 'features/home/presentation/views/main_screen.dart';

void main() {
  runApp(const AlfaMilkApp());
}

class AlfaMilkApp extends StatelessWidget {
  const AlfaMilkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alfa Milk Converter',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const MainScreen(),
    );
  }
}
