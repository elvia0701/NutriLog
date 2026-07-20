import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const NutriLogApp());
}

class NutriLogApp extends StatelessWidget {
  const NutriLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutriLog',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const HomePage(),
    );
  }
}
