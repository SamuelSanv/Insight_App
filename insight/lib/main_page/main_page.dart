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
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with RouteAware {
  bool isDetectionOn = false;
  bool _isDetecting = false;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  final FlutterTts flutterTts = FlutterTts();

  CameraController? _cameraController;
  String? _serverUrl;

  // Battery updates
  final Battery _battery = Battery();
  String _batteryLevel = "Loading...";
  String _connectionStatus = "Checking...";
  final Connectivity _connectivity = Connectivity();
  Timer? _batteryTimer;
  Timer? _lowBattery;

  Timer? _detectionTimer;
  bool _isCameraInitialized = false;

  // Battery state tracking
  bool _isCheckingBattery = false;
  bool _isCheckingBatteryLevel = false;
  bool _hasAnnouncedFullBattery = false;
  bool _hasAnnouncedCharging = false;

  // Error handling
  String? _lastError;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _initRecorder();
      _startBatteryMonitoring();
      _startBatteryLowMonitoring();
      await _getConnectionStatus();
      await _loadServerUrl();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          routeObserver.subscribe(this, ModalRoute.of(context)!);
        } catch (e) {
          _handleError('Route observer subscription failed', e);
        }
      });
    } catch (e) {
      _handleError('App initialization failed', e);
    }
  }

  @override
  void dispose() {
    try {
      _recorder.closeRecorder();
    } catch (e) {
      print('Error closing recorder: $e');
    }

    _batteryTimer?.cancel();
    _lowBattery?.cancel();
    _detectionTimer?.cancel();

    try {
      _cameraController?.dispose();
    } catch (e) {
      print('Error disposing camera: $e');
    }

    try {
      routeObserver.unsubscribe(this);
    } catch (e) {
      print('Error unsubscribing from route observer: $e');
    }

    super.dispose();
  }

  @override
  void didPush() {
    _safeExecute(() async {
      await _speakMainMenuOptions();
      await _refreshStatusAndSpeak();
    });
  }

  @override
  void didPopNext() {
    _safeExecute(() async {
      await _speakMainMenuOptions();
      await _refreshStatusAndSpeak();
    });
  }

  // Error handling utility
  void _handleError(String context, dynamic error) {
    print('❌ $context: $error');
    setState(() {
      _lastError = '$context: ${error.toString()}';
    });

    _consecutiveErrors++;

    // Speak error if TTS is available and not too many consecutive errors
    if (_consecutiveErrors <= _maxConsecutiveErrors) {
      _safeSpeak('Error occurred. $context');
    }
  }

  // Safe execution wrapper
  Future<void> _safeExecute(Future<void> Function() operation) async {
    try {
      await operation();
      _consecutiveErrors = 0; // Reset on success
    } catch (e) {
      _handleError('Operation failed', e);
    }
  }

  // Safe TTS wrapper
  Future<void> _safeSpeak(String message) async {
    try {
      await flutterTts.speak(message);
    } catch (e) {
      print('TTS error: $e');
    }
  }

  Future<void> _refreshStatusAndSpeak() async {
    await _safeExecute(() async {
      await _getBatteryLevel();
      await _getConnectionStatus();
      await _speakMainMenuOptions();
    });
  }

  // TTS for the main page with error handling
  Future<void> _speakMainMenuOptions() async {
    try {
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
    } catch (e) {
      _handleError('Failed to speak main menu options', e);
    }
  }

  // Enhanced camera initialization with better error handling
  Future<void> _initCamera() async {
    try {
      print('📷 Requesting camera permission...');

      // Request camera permission first
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission denied');
      }

      print('📷 Getting available cameras...');
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras available on this device');
      }

      // Find back camera or use first available
      CameraDescription selectedCamera;
      try {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
        print('📷 Using back camera: ${selectedCamera.name}');
      } catch (e) {
        selectedCamera = cameras.first;
        print('⚠️ No back camera found, using: ${selectedCamera.name}');
      }

      print('📷 Initializing camera controller...');
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController?.initialize();

      // Verify initialization
      if (_cameraController?.value.isInitialized != true) {
        throw Exception('Camera failed to initialize properly');
      }

      print('✅ Camera initialized successfully');
    } catch (e) {
      print('❌ Camera initialization failed: $e');
      _cameraController?.dispose();
      _cameraController = null;
      throw Exception('Failed to initialize camera: $e');
    }
  }

  // Mobile frame capture
  Future<File> _captureFrame() async {
    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      print('📸 Taking picture...');
      final XFile picture = await _cameraController!.takePicture();

      // For mobile, create a proper file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = p.join(tempDir.path, fileName);

      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(await picture.readAsBytes());

      // Verify file was created and has content
      if (!await imageFile.exists()) {
        throw Exception('Failed to create image file');
      }

      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        throw Exception('Created image file is empty');
      }

      print('✅ Mobile picture saved: $filePath (${fileSize} bytes)');
      return imageFile;
    } catch (e) {
      print('❌ Failed to capture frame: $e');
      throw Exception('Failed to capture image: $e');
    }
  }

  // Server health check - ping server before detection
  Future<bool> _checkServerHealth() async {
    try {
      if (_serverUrl == null || _serverUrl!.isEmpty) {
        throw Exception('Server URL not configured');
      }

      print('🏥 Checking server health: $_serverUrl');

      // Create a simple GET request to check if server is alive
      final client = http.Client();
      final uri = Uri.parse(_serverUrl!);
      
      // Try to ping the server with a simple GET request
      final response = await client.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Server health check timeout after 10 seconds');
        },
      );

      client.close();

      // Accept any response that indicates server is alive
      // (200, 404, 405 are all fine - server is responding)
      if (response.statusCode >= 200 && response.statusCode < 500) {
        print('✅ Server health check passed: ${response.statusCode}');
        return true;
      } else {
        print('❌ Server health check failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('💥 Server health check error: $e');
      return false;
    }
  }

  // Enhanced server communication with better error handling
  Future<String> _sendFrameToServer(File imageFile) async {
    try {
      if (_serverUrl == null || _serverUrl!.isEmpty) {
        throw Exception('Server URL not configured');
      }

      print('📸 Sending image to server: $_serverUrl');

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_serverUrl!));

      // Add timeout
      final client = http.Client();

      // Mobile implementation
      final fileSize = await imageFile.length();
      print('📁 Mobile image file size: $fileSize bytes');

      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      print('🚀 Sending request...');

      // Send with timeout
      final response = await client
          .send(request)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout after 30 seconds');
            },
          );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        print('✅ Response body: $respStr');

        if (respStr.isEmpty) {
          return 'Server returned empty response';
        }

        try {
          final data = jsonDecode(respStr);
          String result =
              data['detected'] ??
              data['announcement'] ??
              data['result'] ??
              'Nothing detected';

          print('🎯 Detection result: $result');
          return result;
        } catch (e) {
          print('❌ JSON decode error: $e');
          print('Raw response: $respStr');
          // Return the raw response if JSON parsing fails
          return respStr.length > 100 ? 'Server response received' : respStr;
        }
      } else {
        final errorStr = await response.stream.bytesToString();
        print('❌ Server error (${response.statusCode}): $errorStr');

        // Try to parse error response
        try {
          final errorData = jsonDecode(errorStr);
          return errorData['error'] ??
              errorData['message'] ??
              'Server error ${response.statusCode}';
        } catch (e) {
          return 'Server error: ${response.statusCode}';
        }
      }
    } catch (e) {
      print('💥 Network/Request error: $e');

      if (e.toString().contains('timeout')) {
        return 'Connection timeout. Check your network.';
      } else if (e.toString().contains('SocketException')) {
        return 'Network connection failed. Check server URL.';
      } else {
        return 'Connection error: ${e.toString()}';
      }
    }
  }

  // Enhanced recorder initialization
  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();

      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw Exception('Microphone permission denied');
      }

      print('✅ Recorder initialized successfully');
    } catch (e) {
      _handleError('Failed to initialize recorder', e);
    }
  }

  // Enhanced battery monitoring with error handling
  void _startBatteryMonitoring() {
    _safeExecute(() async {
      await _getBatteryLevel();
    });

    _batteryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isCheckingBattery) return;
      _isCheckingBattery = true;

      try {
        await _getBatteryLevel();
        final currentState = await _battery.batteryState;

        // Battery full announcement
        if (currentState == BatteryState.full && !_hasAnnouncedFullBattery) {
          await _safeSpeak("Battery is full.");
          _hasAnnouncedFullBattery = true;
        } else if (currentState != BatteryState.full &&
            _hasAnnouncedFullBattery) {
          _hasAnnouncedFullBattery = false;
        }

        // Charging status announcement
        if (currentState == BatteryState.charging && !_hasAnnouncedCharging) {
          await _safeSpeak("Battery is now charging.");
          _hasAnnouncedCharging = true;
        } else if (currentState != BatteryState.charging &&
            _hasAnnouncedCharging) {
          await _safeSpeak("Charging stopped.");
          _hasAnnouncedCharging = false;
        }
      } catch (e) {
        print("Battery monitoring error: $e");
      } finally {
        _isCheckingBattery = false;
      }
    });
  }

  // Enhanced low battery monitoring
  void _startBatteryLowMonitoring() {
    _lowBattery = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isCheckingBatteryLevel) return;
      _isCheckingBatteryLevel = true;

      try {
        await _getBatteryLevel();
        final currentState = await _battery.batteryState;
        final level = await _battery.batteryLevel;

        if (currentState != BatteryState.charging && level < 15) {
          await _safeSpeak("Battery is low. Please charge.");
        }
      } catch (e) {
        print("Battery level monitoring error: $e");
      } finally {
        _isCheckingBatteryLevel = false;
      }
    });
  }

  // Enhanced microphone permission handling
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
        await _safeSpeak(
          "Microphone permission is permanently denied. Please enable it in system settings.",
        );
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      _handleError("Microphone permission check failed", e);
      return false;
    }
  }

  // Enhanced voice command with error handling
  Future<void> _onVoiceCommand() async {
    await _safeExecute(() async {
      final granted = await _requestMicPermission();
      if (!granted) {
        await _safeSpeak(
          "Microphone permission is required for voice commands.",
        );
        return;
      }

      if (!_isRecording) {
        try {
          await _recorder.startRecorder(
            toFile: 'voice_command.wav',
            codec: Codec.pcm16WAV,
          );
          setState(() {
            _isRecording = true;
          });
          await _safeSpeak("Recording started. Speak now.");
        } catch (e) {
          setState(() {
            _isRecording = false;
          });
          throw Exception('Failed to start recording: $e');
        }
      } else {
        try {
          final path = await _recorder.stopRecorder();
          setState(() {
            _isRecording = false;
          });
          print('Recording saved at: $path');
          await _safeSpeak("Recording stopped.");
        } catch (e) {
          setState(() {
            _isRecording = false;
          });
          throw Exception('Failed to stop recording: $e');
        }
      }
    });
  }

  // Enhanced detection toggle with comprehensive error handling
  Future<void> _toggleDetection() async {
    await _safeExecute(() async {
      if (_isDetecting && isDetectionOn) {
        await _safeSpeak("Detection is already running. Please wait.");
        return;
      }

      // Check server configuration
      if (_serverUrl == null || _serverUrl!.isEmpty) {
        await _safeSpeak(
          "Server URL not configured. Please check server settings.",
        );
        return;
      }

      if (!isDetectionOn) {
        // Before starting detection, check server health
        await _safeSpeak("Checking server connection...");
        
        final isServerHealthy = await _checkServerHealth();
        if (!isServerHealthy) {
          await _safeSpeak(
            "Server is not responding. Please check server settings and try again.",
          );
          return;
        }
        
        await _safeSpeak("Server connection verified. Starting detection...");
      }

      setState(() => isDetectionOn = !isDetectionOn);

      if (isDetectionOn) {
        await _startContinuousDetection();
      } else {
        await _safeSpeak("Stopping detection...");
        await _stopContinuousDetection();
      }
    });
  }

  Future<void> _startContinuousDetection() async {
    try {
      // Initialize camera if needed
      if (!_isCameraInitialized) {
        print('📷 Initializing camera for continuous detection...');
        await _initCamera();
        _isCameraInitialized = true;
        print('✅ Camera ready for continuous detection');
      }

      // Start periodic detection
      _detectionTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (!isDetectionOn || _isDetecting) return;
        await _performSingleDetection();
      });

      // Perform first detection immediately
      await _performSingleDetection();
    } catch (e) {
      print('💥 Failed to start continuous detection: $e');
      await _safeSpeak("Failed to start detection. ${e.toString()}");
      await _stopContinuousDetection();
    }
  }

  Future<void> _stopContinuousDetection() async {
    print('🛑 Stopping continuous detection...');

    // Cancel timer first
    if (_detectionTimer != null) {
      _detectionTimer!.cancel();
      _detectionTimer = null;
      print('⏹️ Detection timer cancelled');
    }

    // Update state
    setState(() {
      isDetectionOn = false;
      _isDetecting = false;
    });

    // Dispose camera safely
    try {
      if (_isCameraInitialized && _cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
        _isCameraInitialized = false;
        print('📷 Camera disposed after continuous detection');
      }
    } catch (e) {
      print('⚠️ Error disposing camera: $e');
    }

    print('✅ Continuous detection fully stopped');
  }

  Future<void> _performSingleDetection() async {
    if (_isDetecting || !isDetectionOn || _detectionTimer == null) return;

    _isDetecting = true;

    try {
      print('🔍 Performing detection cycle...');

      // Double-check detection is still on
      if (!isDetectionOn) {
        return;
      }

      // Capture frame
      final imageData = await _captureFrame();

      // Check again if detection was stopped during capture
      if (!isDetectionOn) {
        // Clean up mobile file
        try {
          await imageData.delete();
        } catch (e) {
          print('⚠️ Failed to delete temp file: $e');
        }
        return;
      }

      // Send to server
      final result = await _sendFrameToServer(imageData);

      // Announce results if detection is still on and something was detected
      if (isDetectionOn &&
          result != "No objects detected nearby." &&
          result != "Nothing detected" &&
          result.isNotEmpty) {
        print('🎯 Detection found: $result');
        await _safeSpeak("Detected: $result");
      } else {
        print('🔍 No objects detected in this cycle');
      }

      // Clean up mobile file
      try {
        await imageData.delete();
      } catch (e) {
        print('⚠️ Failed to delete temp file: $e');
      }
    } catch (e) {
      print('💥 Detection cycle error: $e');

      // Don't stop detection for individual errors, but announce severe issues
      if (e.toString().contains('Camera') ||
          e.toString().contains('permission')) {
        await _safeSpeak("Detection error. Camera issue detected.");
        // Stop detection if it's a camera-related error
        await _stopContinuousDetection();
      }
    } finally {
      _isDetecting = false;
    }
  }

  // Enhanced TTS settings navigation
  Future<void> _openTTSSettings() async {
    await _safeExecute(() async {
      await _safeSpeak("Opening TTS settings");
      Navigator.pushNamed(context, '/tts-settings');
    });
  }

  // Enhanced emergency contact navigation
  Future<void> _emergencyCall() async {
    await _safeExecute(() async {
      print("Emergency call triggered");
      await _safeSpeak("Emergency contact opened");
      Navigator.pushNamed(context, '/emergency');
    });
  }

  // Enhanced battery level getter
  Future<void> _getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      setState(() {
        _batteryLevel = "$level%";
      });
    } catch (e) {
      print("Failed to get battery level: $e");
      setState(() {
        _batteryLevel = "Unknown";
      });
    }
  }

  // Enhanced connection status getter
  Future<void> _getConnectionStatus() async {
    try {
      final result = await _connectivity.checkConnectivity();
      setState(() {
        _connectionStatus = _getReadableStatus(result);
      });
    } catch (e) {
      print("Failed to get connection status: $e");
      setState(() {
        _connectionStatus = "Unknown";
      });
    }
  }

  // Enhanced server URL loading
  Future<void> _loadServerUrl() async {
    try {
      final url = await SettingsService.getServerUrl();
      setState(() {
        _serverUrl = url;
      });
    } catch (e) {
      _handleError("Failed to load server URL", e);
    }
  }

  // Enhanced server settings navigation
  Future<void> _openServerSettings() async {
    await _safeExecute(() async {
      await _safeSpeak("Opening server settings");
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ServerSettingsPage()),
      );
      // Reload server URL when returning
      await _loadServerUrl();
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
              // Voice Command Button
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

              // Detection Button
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

              // TTS Settings Button
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

              // Emergency Contact Button
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

              // Server Settings Button
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

              // Status Card
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        "🔋 Battery: $_batteryLevel",
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "📶 Connection: $_connectionStatus",
                        style: const TextStyle(color: Colors.white),
                      ),
                      // Show last error if any
                      if (_lastError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "⚠️ ${_lastError!}",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
