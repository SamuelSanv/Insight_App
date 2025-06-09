import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool isDetectionOn = false;

  void _toggleDetection() {
    setState(() {
      isDetectionOn = !isDetectionOn;
    });

    final status = isDetectionOn ? 'started' : 'stopped';
    print('Object detection $status');
  }

  void _onVoiceCommand() {
    print("Voice command activated");
  }

  void _openTTSSettings() {
    Navigator.pushNamed(context, '/tts-settings');
  }

  void _emergencyCall() {
    print("Emergency call triggered");
    Navigator.pushNamed(context, '/emergency');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('InSight Control'),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: _onVoiceCommand,
                icon: const Icon(Icons.mic),
                label: const Text('Voice Command'),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDetectionOn ? Colors.red : Colors.green,
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: _toggleDetection,
                icon: Icon(isDetectionOn ? Icons.stop : Icons.play_arrow),
                label: Text(isDetectionOn ? 'Stop Detection' : 'Start Detection'),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: _openTTSSettings,
                icon: const Icon(Icons.language),
                label: const Text('TTS Settings'),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: _emergencyCall,
                icon: const Icon(Icons.warning),
                label: const Text('Emergency Contact'),
              ),
              const Spacer(),

              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: const [
                      Text("🔋 Battery: 92%", style: TextStyle(color: Colors.white)),
                      SizedBox(height: 8),
                      Text("📶 Connection: Stable", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
