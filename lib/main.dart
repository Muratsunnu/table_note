import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/table_provider.dart';
import 'screens/table_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => TableProvider(),
      child: TableNoteApp(),
    ),
  );
}

class TableNoteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Table Note',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TableScreen(),
    );
  }
}