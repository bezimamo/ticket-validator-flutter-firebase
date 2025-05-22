import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'validate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Ticket Validator',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const ValidateScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
