import 'package:flutter/material.dart';
import 'package:insight/system/emergency.dart';
import 'package:insight/system/tts_settings_page.dart';
import 'insideApp/welcome_page.dart';
import 'main_page/main_page.dart';

// This RouteObserver to support route-aware screens
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
      navigatorObservers: [routeObserver], // 👈 This enables MainPage to detect when it's shown
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/main': (context) => const MainPage(),
        '/tts-settings': (context) => const TTSSettingsPage(),
        '/emergency' : (context) => const EmergencyPage(),
      },
    );
  }
}
