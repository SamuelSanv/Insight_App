import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';


final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with RouteAware {
  bool isDetectionOn = false;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  final FlutterTts flutterTts = FlutterTts();

  final Battery _battery = Battery();
  String _batteryLevel = "Loading...";
  String _connectionStatus = "Checking...";
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _initRecorder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    });
    _getBatteryLevel();
    _getConnectionStatus();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await Permission.microphone.request();
  }


  @override
  void dispose() {
    _recorder.closeRecorder();
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

  Future<void> _speakMainMenuOptions() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);

    final batteryInfo = _batteryLevel.isNotEmpty ? _batteryLevel : "unknown";
    final connectionInfo = _connectionStatus.isNotEmpty ? _connectionStatus : "unknown";

    final message =
        "Welcome to the main menu. "
        "Options are: Voice Command, Start Detection, TTS Settings, and Emergency Contact. "
        "Choose one option. "
        "Your battery level is $batteryInfo. "
        "The current connection is $connectionInfo.";

    await flutterTts.speak(message);
  }

  //Request the mic permission
  Future<bool> _requestMicPermission() async {
    try {
      var status = await Permission.microphone.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied || status.isRestricted || status.isLimited) {
        status = await Permission.microphone.request();
        return status.isGranted;
      }

      if (status.isPermanentlyDenied) {
        // You can optionally open settings here
        await flutterTts.speak("Microphone permission is permanently denied. Please enable it in system settings.");
        openAppSettings(); // opens app settings screen
        return false;
      }

      return false;
    } catch (e) {
      print("Microphone permission check failed: $e");
      await flutterTts.speak("Failed to access microphone permission.");
      return false;
    }
  }



  //Method of the Voice command button
  Future<void> _onVoiceCommand() async {
    final granted = await _requestMicPermission();
    if (!granted) {
      await flutterTts.speak("Microphone permission is denied. Please enable it in settings.");
      if (await Permission.microphone.isPermanentlyDenied) {
        await openAppSettings(); // Opens device settings for your app
      }
      return;
    }

    if (!_isRecording) {
      await _recorder.startRecorder(
        toFile: 'voice_command.wav',
        codec: Codec.pcm16WAV,
      );
      setState(() {
        _isRecording = true;
      });
      await flutterTts.speak("Recording started. Speak now.");
    } else {
      final path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
      print('Recording saved at: $path');
      await flutterTts.speak("Voice command activated");
    }
  }


  //Method of the Detection button
  Future<void> _toggleDetection() async {
    setState(() {
      isDetectionOn = !isDetectionOn;
    });

    final statusMessage = isDetectionOn ? "Detection started" : "Detection stopped";
    print('Object detection $statusMessage');
    await flutterTts.speak(statusMessage);
  }

  //Method of the TTS Setting button
  Future<void> _openTTSSettings() async {
    await flutterTts.speak("Opening TTS settings");
    Navigator.pushNamed(context, '/tts-settings');
  }

  //Method of the Emergency Contact button
  Future<void> _emergencyCall() async {
    print("Emergency call triggered");
    await flutterTts.speak("Emergency contact opened");
    Navigator.pushNamed(context, '/emergency');
  }

  //Method for getting the battery level
  Future<void> _getBatteryLevel() async {
    final level = await _battery.batteryLevel;
    setState(() {
      _batteryLevel = "$level%";
    });
  }

  //Method of getting the connection status
  Future<void> _getConnectionStatus() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      _connectionStatus = _getReadableStatus(result);
    });
  }

  // Get the status label for the connection
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
                label: Text(_isRecording ? 'Stop Recording' : 'Voice Command'),
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
                      const SizedBox(height: 8),
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
