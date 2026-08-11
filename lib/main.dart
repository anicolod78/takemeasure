import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const TakeMeasureApp());
}

class TakeMeasureApp extends StatelessWidget {
  const TakeMeasureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Take Measure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
