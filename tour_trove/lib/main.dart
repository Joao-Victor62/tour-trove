import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'features/shell/home_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light, // centralize seu tema
      home: const HomeShell(),
    );
  }
}
