import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/table_provider.dart';
import 'providers/template_provider.dart';
import 'screens/table_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TableProvider()),
        ChangeNotifierProvider(create: (context) => TemplateProvider()),
      ],
      child: TableNoteApp(),
    ),
  );
}

class TableNoteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Table Note',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TableScreen(),
    );
  }
}