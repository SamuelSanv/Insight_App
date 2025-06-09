import 'package:flutter/material.dart';

class TTSSettingsPage extends StatelessWidget {
  const TTSSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TTS Settings'),
      ),
      body: const Center(
        child: Text(
          'TTS Settings screen coming soon...',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
