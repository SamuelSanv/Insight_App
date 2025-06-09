import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../system/tts_settings_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speakWelcomeMessage();
  }

  Future<void> _speakWelcomeMessage() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak("Welcome to InSight. Tap anywhere on the screen to begin.");
  }

  void _goToNextScreen() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToNextScreen,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.visibility_off,
                  size: 120,
                  color: Colors.white,
                  semanticLabel: 'InSight App Logo',
                ),
                SizedBox(height: 20),
                Text(
                  'InSight',
                  style: TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  semanticsLabel: 'InSight App, tap anywhere to continue.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
