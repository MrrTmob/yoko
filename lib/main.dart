import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yoko/test_keyboard.dart';
import 'package:yoko/test_ui.dart';

void main() {
  //initializeDateFormatting().then((_) => runApp(const MyApp()));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: ExampleApp(),
      );
}