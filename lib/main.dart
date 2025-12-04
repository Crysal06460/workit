import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const WorkItApp());
}

class WorkItApp extends StatelessWidget {
  const WorkItApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0066FF)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      textTheme: Typography.blackMountainView,
    );

    return MaterialApp(
      title: 'WorkIt',
      theme: theme,
      home: const EntryScreen(),
    );
  }
}
