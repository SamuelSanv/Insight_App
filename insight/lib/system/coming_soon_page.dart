import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ComingSoonPage extends StatefulWidget {
  final String featureName;
  final String description;
  final IconData icon;

  const ComingSoonPage({
    super.key,
    required this.featureName,
    required this.description,
    required this.icon,
  });

  @override
  State<ComingSoonPage> createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends State<ComingSoonPage> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTTS();
    _speakComingSoon();
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.8);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speakComingSoon() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _safeSpeak(
      "${widget.featureName} feature is coming soon. ${widget.description}",
    );
  }

  Future<void> _safeSpeak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.featureName),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Feature Icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 80, color: Colors.blue[700]),
              ),

              const SizedBox(height: 32),

              // Coming Soon Text
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Feature Name
              Text(
                widget.featureName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Description
              Text(
                widget.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Progress Indicator
              Column(
                children: [
                  Text(
                    'Development in Progress',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue[700]!,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Back Button
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Main'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
