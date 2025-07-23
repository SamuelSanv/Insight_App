import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final FlutterTts _flutterTts = FlutterTts();
  List<EmergencyContact> _emergencyContacts = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTTS();
    _loadContacts();
    _speakWelcome();
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.8);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speakWelcome() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _safeSpeak(
      "Emergency contacts page. You can add, edit, or call emergency contacts. Tap the emergency call button to quickly dial your first contact.",
    );
  }

  Future<void> _safeSpeak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList('emergency_contacts') ?? [];

    setState(() {
      _emergencyContacts = contactsJson
          .map((json) => EmergencyContact.fromJson(json))
          .toList();
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = _emergencyContacts
        .map((contact) => contact.toJson())
        .toList();
    await prefs.setStringList('emergency_contacts', contactsJson);
  }

  Future<void> _addContact() async {
    if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
      final newContact = EmergencyContact(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      setState(() {
        _emergencyContacts.add(newContact);
      });

      await _saveContacts();
      await _safeSpeak("Contact ${newContact.name} added successfully.");

      _nameController.clear();
      _phoneController.clear();
      Navigator.of(context).pop();
    } else {
      await _safeSpeak("Please enter both name and phone number.");
    }
  }

  Future<void> _deleteContact(int index) async {
    final contact = _emergencyContacts[index];
    setState(() {
      _emergencyContacts.removeAt(index);
    });
    await _saveContacts();
    await _safeSpeak("Contact ${contact.name} deleted.");
  }

  Future<void> _callContact(EmergencyContact contact) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: contact.phone);
      if (await canLaunchUrl(phoneUri)) {
        await _safeSpeak("Calling ${contact.name}");
        await launchUrl(phoneUri);
      } else {
        await _safeSpeak("Cannot make phone calls on this device.");
      }
    } catch (e) {
      await _safeSpeak("Error making phone call.");
    }
  }

  Future<void> _emergencyCall() async {
    if (_emergencyContacts.isNotEmpty) {
      await _callContact(_emergencyContacts.first);
    } else {
      await _safeSpeak(
        "No emergency contacts available. Please add a contact first.",
      );
    }
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                hintText: 'e.g., Family Doctor',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g., +1234567890',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(minimumSize: const Size(120, 60)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addContact,
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 60)),
            child: const Text('Add Contact'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddContactDialog,
            tooltip: 'Add Emergency Contact',
          ),
        ],
      ),
      body: Column(
        children: [
          // Emergency Call Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _emergencyCall,
              icon: const Icon(Icons.emergency, size: 32),
              label: const Text(
                'EMERGENCY CALL',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                minimumSize: const Size.fromHeight(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _emergencyContacts.isEmpty
                  ? 'Add emergency contacts below. The first contact will be called when using the emergency button.'
                  : 'Tap any contact to call them, or use the emergency button above to call ${_emergencyContacts.first.name}.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Contacts List
          Expanded(
            child: _emergencyContacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contact_phone,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Emergency Contacts',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add your first contact',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _emergencyContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _emergencyContacts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red[100],
                            child: Text(
                              contact.name[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            contact.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(contact.phone),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.phone,
                                  color: Colors.green,
                                ),
                                onPressed: () => _callContact(contact),
                                tooltip: 'Call ${contact.name}',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteContact(index),
                                tooltip: 'Delete Contact',
                              ),
                            ],
                          ),
                          onTap: () => _callContact(contact),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Add Emergency Contact',
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _flutterTts.stop();
    super.dispose();
  }
}

class EmergencyContact {
  final String name;
  final String phone;

  EmergencyContact({required this.name, required this.phone});

  Map<String, dynamic> toMap() {
    return {'name': name, 'phone': phone};
  }

  String toJson() {
    return '${toMap()['name']}|${toMap()['phone']}';
  }

  static EmergencyContact fromJson(String json) {
    final parts = json.split('|');
    return EmergencyContact(name: parts[0], phone: parts[1]);
  }
}
