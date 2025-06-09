import 'package:flutter/material.dart';
import 'package:insight/system/emergency.dart';
import 'package:insight/system/tts_settings_page.dart';
import 'insideApp/welcome_page.dart';
import 'main_page/main_page.dart';

void main() {
  runApp(const InSightApp());
}

class InSightApp extends StatelessWidget {
  const InSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InSight App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/main': (context) => const MainPage(),
        '/tts-settings': (context) => const TTSSettingsPage(),
        '/emergency' : (context) => const Emergency(),
      },
    );
  }
}
