import 'dart:convert';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:insight/system/settings_service.dart';
import 'package:insight/system/server_settings_page.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with RouteAware {
  bool isDetectionOn = false;
  bool _isDetecting = false; //For the detection button
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  final FlutterTts flutterTts = FlutterTts();

  CameraController? _cameraController;
  String? _serverUrl;

  //Battery updates
  final Battery _battery = Battery();
  String _batteryLevel = "Loading...";
  String _connectionStatus = "Checking...";
  final Connectivity _connectivity = Connectivity();
  Timer? _batteryTimer;
  Timer? _lowBattery;
  // StreamSubscription<BatteryState>? _batteryStateSubscription;
  bool _isCheckingBattery = false;
  bool _isCheckingBatteryLevel = false;
  bool _hasAnnouncedFullBattery = false;
  bool _hasAnnouncedCharging = false;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _startBatteryMonitoring();
    _startBatteryLowMonitoring();
    _getConnectionStatus();
    _loadServerUrl(); // Load server URL from settings

    WidgetsBinding.instance.addPostFrameCallback((_) {
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    });
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _batteryTimer?.cancel();
    _lowBattery?.cancel();
    _cameraController?.dispose();
    // _batteryStateSubscription?.cancel();
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

  // TTS for the main page
  Future<void> _speakMainMenuOptions() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);

    final batteryInfo = _batteryLevel.isNotEmpty ? _batteryLevel : "unknown";
    final connectionInfo = _connectionStatus.isNotEmpty
        ? _connectionStatus
        : "unknown";

    final message =
        "Welcome to the main menu. "
        "Your Options are: "
        "Voice Command, Start Detection, TTS Settings, and Emergency Contact. "
        "Choose one option. "
        "Your battery level is $batteryInfo. "
        "The current connection is $connectionInfo.";

    await flutterTts.speak(message);
  }

  // Camera initialization
  Future<void> _initCamera() async {
    try {
      print('📷 Getting available cameras...');
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras available on this device');
      }

      // Find back camera
      CameraDescription? backCamera;
      try {
        backCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
      } catch (e) {
        // If no back camera, use the first available camera
        backCamera = cameras.first;
        print('⚠️ No back camera found, using: ${backCamera.name}');
      }

      print('📷 Initializing camera: ${backCamera.name}');
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController?.initialize();
      print('✅ Camera initialized successfully');
    } catch (e) {
      print('❌ Camera initialization failed: $e');
      throw Exception('Failed to initialize camera: $e');
    }
  }

  // Capture one frame
  Future<File> _captureFrame() async {
    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      print('📸 Taking picture...');
      final XFile picture = await _cameraController!.takePicture();

      // Create a proper file path
      final tempDir = await getTemporaryDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = p.join(tempDir.path, fileName);

      // Copy the XFile to our target location
      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(await picture.readAsBytes());

      print('✅ Picture saved to: $filePath');
      return imageFile;
    } catch (e) {
      print('❌ Failed to capture frame: $e');
      throw Exception('Failed to capture image: $e');
    }
  }

  // Send frame to server
  Future<String> _sendFrameToServer(File imageFile) async {
    try {
      print('📸 Sending image to server: $_serverUrl');
      print('📁 Image file size: ${await imageFile.length()} bytes');

      // Create multipart request to root endpoint
      final request = http.MultipartRequest('POST', Uri.parse(_serverUrl!));

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      print('🚀 Sending request...');
      final response = await request.send();

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        print('✅ Response body: $respStr');

        try {
          final data = jsonDecode(respStr);

          // Handle both 'detected' and 'announcement' fields
          String result =
              data['detected'] ?? data['announcement'] ?? 'Nothing detected';

          print('🎯 Detection result: $result');
          return result;
        } catch (e) {
          print('❌ JSON decode error: $e');
          print('Raw response: $respStr');
          return 'Server response format error';
        }
      } else {
        final errorStr = await response.stream.bytesToString();
        print('❌ Server error (${response.statusCode}): $errorStr');

        // Try to parse error response
        try {
          final errorData = jsonDecode(errorStr);
          return errorData['detected'] ??
              errorData['error'] ??
              'Server error ${response.statusCode}';
        } catch (e) {
          return 'Server error: ${response.statusCode}';
        }
      }
    } catch (e) {
      print('💥 Network/Request error: $e');
      return 'Connection error: ${e.toString()}';
    }
  }

  //To init the Mic
  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await Permission.microphone.request();
  }

  //Battery level and state monitoring
  void _startBatteryMonitoring() {
    _getBatteryLevel();

    _batteryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // Check the state of the battery every second
      if (_isCheckingBattery) return;
      _isCheckingBattery = true;

      try {
        print(
          "⏱ Checking battery at ${DateTime.now()}",
        ); // write every time the checking is done
        await _getBatteryLevel();

        final currentState = await _battery.batteryState;

        // Check if the battery is full or not
        if (currentState == BatteryState.full && !_hasAnnouncedFullBattery) {
          await flutterTts.speak("Battery is full.");
          _hasAnnouncedFullBattery = true;
        } else if (currentState != BatteryState.full &&
            _hasAnnouncedFullBattery) {
          // When battery has already announced it is full
          _hasAnnouncedFullBattery = false;
        }

        //Check if the battery is plug in or unplug
        if (currentState == BatteryState.charging && !_hasAnnouncedCharging) {
          await flutterTts.speak("Battery is now charging.");
          _hasAnnouncedCharging = true;
        } else if (currentState != BatteryState.charging &&
            _hasAnnouncedCharging) {
          // When still charging but already announced
          await flutterTts.speak("Charging stopped!.");
          _hasAnnouncedCharging = false;
        }
      } catch (e) {
        print("Battery monitoring error: $e");
      } finally {
        _isCheckingBattery = false;
      }
    });
  }

  // Battery level Monitoring
  void _startBatteryLowMonitoring() {
    _getBatteryLevel();

    // Check if the battery is low every 30 seconds
    _lowBattery = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isCheckingBatteryLevel) return;
      _isCheckingBatteryLevel = true;

      try {
        print(
          "⏱ Checking low battery at ${DateTime.now()}",
        ); // write every time the checking is done
        await _getBatteryLevel();

        final currentState = await _battery.batteryState;
        final level = await _battery.batteryLevel;

        // Check if the battery level is at 15%
        if (currentState != BatteryState.charging && level < 15) {
          await flutterTts.speak("Battery is low... Please charge!!.");
        }
      } catch (e) {
        print("Battery monitoring level error: $e");
      } finally {
        _isCheckingBatteryLevel = false;
      }
    });
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
        await flutterTts.speak(
          "Microphone permission is permanently denied. Please enable it in system settings.",
        );
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
      await flutterTts.speak(
        "Microphone permission is denied. Please enable it in settings.",
      );
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
      await flutterTts.speak("Recording stopped...");
    }
  }

  //Method of the Detection button
  Future<void> _toggleDetection() async {
    if (_isDetecting) {
      await flutterTts.speak("Detection is already running. Please wait.");
      return;
    }

    // Check if server URL is configured
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      await flutterTts.speak(
        "Server URL not configured. Please check server settings.",
      );
      return;
    }

    print('🔄 Starting detection process...');
    setState(() => isDetectionOn = !isDetectionOn);

    if (isDetectionOn) {
      _isDetecting = true;
      await flutterTts.speak("Starting detection...");

      try {
        print('📷 Initializing camera...');
        await _initCamera();

        print('📸 Capturing frame...');
        final imageFile = await _captureFrame();

        print('🔍 Processing with server...');
        final result = await _sendFrameToServer(imageFile);

        print('🎉 Detection completed: $result');
        await flutterTts.speak("Detection result: $result");

        // Clean up the temporary image file
        try {
          await imageFile.delete();
          print('🗑️ Temporary image file cleaned up');
        } catch (e) {
          print('⚠️ Failed to delete temp file: $e');
        }
      } catch (e) {
        print('💥 Detection error: $e');
        String errorMessage;

        if (e.toString().contains('Connection')) {
          errorMessage =
              "Cannot connect to server. Check your network and server settings.";
        } else if (e.toString().contains('Camera')) {
          errorMessage = "Camera error. Please check camera permissions.";
        } else {
          errorMessage = "Detection failed. Please try again.";
        }

        await flutterTts.speak(errorMessage);
      } finally {
        // Clean up camera and reset state
        try {
          await _cameraController?.dispose();
          _cameraController = null;
          print('📷 Camera disposed');
        } catch (e) {
          print('⚠️ Error disposing camera: $e');
        }

        _isDetecting = false;
        setState(() => isDetectionOn = false);
        await flutterTts.speak("Detection stopped.");
        print('✅ Detection process completed');
      }
    } else {
      await flutterTts.speak("Detection stopped.");
    }
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

  // Load server URL from settings
  Future<void> _loadServerUrl() async {
    final url = await SettingsService.getServerUrl();
    setState(() {
      _serverUrl = url;
    });
  }

  // Method to open server settings page
  Future<void> _openServerSettings() async {
    await flutterTts.speak("Opening server settings");
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ServerSettingsPage()),
    );

    // Reload server URL when returning from settings page
    await _loadServerUrl();
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
                  backgroundColor: _isRecording
                      ? Colors.redAccent
                      : Colors.blue,
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
                label: Text(
                  isDetectionOn ? 'Stop Detection' : 'Start Detection',
                ),
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
              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: _openServerSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Server Settings'),
              ),
              const Spacer(),

              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        "🔋 Battery: $_batteryLevel",
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "📶 Connection: $_connectionStatus",
                        style: TextStyle(color: Colors.white),
                      ),
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
