import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  List<Map<String, String>> _contacts = [];
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlayingAlarm = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _player.openPlayer();
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? contactsJson = prefs.getString('emergency_contacts');
    if (contactsJson != null) {
      final List<dynamic> decoded = jsonDecode(contactsJson);
      setState(() {
        _contacts = decoded
            .map<Map<String, String>>(
                (item) => {'name': item['name'], 'phone': item['phone']})
            .toList();
      });
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_contacts);
    await prefs.setString('emergency_contacts', encoded);
  }

  void _addContact() {
    String name = '';
    String phone = '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (value) => name = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              onChanged: (value) => phone = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (name.isNotEmpty && phone.isNotEmpty) {
                setState(() {
                  _contacts.add({'name': name, 'phone': phone});
                });
                _saveContacts(); // ✅ save after adding
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch dialer')),
      );
    }
  }

  Future<void> _sendSMS(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch SMS app')),
      );
    }
  }

  Future<void> _playAlarm() async {
    if (_isPlayingAlarm) {
      await _player.stopPlayer();
      setState(() => _isPlayingAlarm = false);
    } else {
      await Permission.microphone.request();
      await _player.startPlayer(
        fromURI: 'https://www.soundjay.com/button/beep-07.wav',
        whenFinished: () => setState(() => _isPlayingAlarm = false),
      );
      setState(() => _isPlayingAlarm = true);
    }
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
    _saveContacts(); // ✅ save after removing
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: _contacts.isEmpty
                  ? const Center(
                child: Text('No contacts added',
                    style: TextStyle(color: Colors.white54)),
              )
                  : ListView.builder(
                itemCount: _contacts.length,
                itemBuilder: (_, index) {
                  final contact = _contacts[index];
                  return Card(
                    color: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      title: Text(contact['name']!,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(contact['phone']!,
                          style: const TextStyle(color: Colors.white70)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.call,
                                color: Colors.greenAccent),
                            onPressed: () =>
                                _makeCall(contact['phone']!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.message,
                                color: Colors.amberAccent),
                            onPressed: () =>
                                _sendSMS(contact['phone']!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () => _removeContact(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                _isPlayingAlarm ? Colors.grey : Colors.redAccent,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _playAlarm,
              icon: Icon(
                  _isPlayingAlarm ? Icons.stop : Icons.warning_amber_rounded),
              label: Text(_isPlayingAlarm ? 'Stop Alarm' : 'Trigger Alarm'),
            ),
          ],
        ),
      ),
    );
  }
}
