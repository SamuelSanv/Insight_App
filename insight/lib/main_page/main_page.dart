import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Make sure this matches what you added in main.dart
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with RouteAware {
  //Variables
  bool isDetectionOn = false;
  final FlutterTts flutterTts = FlutterTts();

  Battery _battery = Battery();
  String _batteryLevel = "Loading...";
  String _connectionStatus = "Checking...";
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    });

    _getBatteryLevel();
    _getConnectionStatus();
  }


  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _speakMainMenuOptions();
    _refreshStatusAndSpeak();
  }

  @override
  void didPopNext() {
    _speakMainMenuOptions();
    _refreshStatusAndSpeak();
  }

  Future<void> _refreshStatusAndSpeak() async {
    await _getBatteryLevel();
    await _getConnectionStatus();
    await _speakMainMenuOptions();
  }


  //The first song while opening the app main page
  Future<void> _speakMainMenuOptions() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);

    final batteryInfo = _batteryLevel.isNotEmpty ? _batteryLevel : "unknown";
    final connectionInfo = _connectionStatus.isNotEmpty ? _connectionStatus : "unknown";

    final message =
        "Welcome to the main menu. "
        "Options are: Voice Command, Start Detection, TTS Settings, and Emergency Contact..."
        "Choose one option..."
        "And your Battery level is $batteryInfo. "
        "with the Current connection used is $connectionInfo.";

    await flutterTts.speak(message);
  }

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

  //About the battery level
  Future<void> _getBatteryLevel() async {
    final level = await _battery.batteryLevel;
    setState(() {
      _batteryLevel = "$level%";
    });
  }

  //About the connection
  Future<void> _getConnectionStatus() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      _connectionStatus = _getReadableStatus(result);
    });
  }

  String _getReadableStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return "Wi-Fi";
      case ConnectivityResult.mobile:
        return "Mobile Data";
      case ConnectivityResult.ethernet:
        return "Ethernet";
      case ConnectivityResult.bluetooth:
        return "Bluetooth";
      case ConnectivityResult.none:
      default:
        return "No Connection";
    }
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
                    children: [
                      Text("🔋 Battery: $_batteryLevel", style: TextStyle(color: Colors.white)),
                      SizedBox(height: 8),
                      Text("📶 Connection: $_connectionStatus", style: TextStyle(color: Colors.white)),
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
