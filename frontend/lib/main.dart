import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:seeforyou_app/firebase_options.dart';
import 'package:seeforyou_app/screens/root/root_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeeForYou',
      debugShowCheckedModeBanner: false,
      home: const RootScreen(),
    );
  }
}
