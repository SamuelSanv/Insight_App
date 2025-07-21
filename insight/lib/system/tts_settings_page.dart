import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSSettingsPage extends StatefulWidget {
  const TTSSettingsPage({super.key});

  @override
  State<TTSSettingsPage> createState() => _TTSSettingsPageState();
}

class _TTSSettingsPageState extends State<TTSSettingsPage> {
  final FlutterTts _flutterTts = FlutterTts();
  String _selectedLanguage = '';
  double _speechRate = 0.5;
  List<String> _languages = [];

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = (await _flutterTts.getLanguages).cast<String>();
      print('🌍 Loaded languages: $langs');

      final uniqueLangs = langs.toSet().toList();

      if (uniqueLangs.isEmpty) {
        uniqueLangs.addAll(['en-US', 'fr-FR', 'es-ES']);
        print('⚠️ Using fallback languages.');
      }

      setState(() {
        _languages = uniqueLangs;
        _selectedLanguage =
        _languages.contains('en-US') ? 'en-US' : _languages.first;
      });
    } catch (e) {
      print('❌ Error loading languages: $e');
      setState(() {
        _languages = ['en-US'];
        _selectedLanguage = 'en-US';
      });
    }
  }

  Future<void> _applySettings() async {
    if (_selectedLanguage.isNotEmpty) {
      await _flutterTts.setLanguage(_selectedLanguage);
      await _flutterTts.setSpeechRate(_speechRate);
    }
  }

  Future<void> _testVoice() async {
    await _applySettings();
    await _flutterTts.speak("This is a test message.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // dark theme
      appBar: AppBar(
        title: const Text('TTS Settings'),
        backgroundColor: Colors.black,
      ),
      body: _languages.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sound/Language',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedLanguage.isEmpty
                          ? null
                          : _selectedLanguage,
                      dropdownColor: Colors.grey[850],
                      style: const TextStyle(color: Colors.white),
                      iconEnabledColor: Colors.white,
                      items: _languages.map<DropdownMenuItem<String>>(
                              (lang) {
                            return DropdownMenuItem<String>(
                              value: lang,
                              child: Text(lang == 'en-US'
                                  ? 'English (default)'
                                  : lang),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLanguage = value!;
                        });
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speech Rate',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Slider(
                      value: _speechRate,
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      activeColor: Colors.blueAccent,
                      label: _speechRate.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          _speechRate = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _testVoice,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test Voice'),
            ),
          ],
        ),
      ),
    );
  }
}
