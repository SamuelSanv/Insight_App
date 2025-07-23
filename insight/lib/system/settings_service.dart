import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _serverUrlKey = 'server_url';
  static const String _defaultServerUrl = 'https://your-default-server.com'; // Replace with your actual default URL

  // Get the stored server URL, or return the default if none is set
  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? _defaultServerUrl;
  }

  // Save a new server URL
  static Future<bool> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_serverUrlKey, url);
  }
}
