import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tracker_tag.dart';

class StorageService {
  static const String _tagsKey = 'saved_tags';
  static const String _userKey = 'user_display_name';
  static const String _userIdKey = 'user_id';

  // --- USERNAME LOGIC ---
  static Future<void> saveUsername(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, name);
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey) ?? "Guest User";
  }

  static Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  // --- USER ID LOGIC ---
  static Future<void> saveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // --- TAGS LOGIC ---
  static Future<void> saveTags(List<TrackerTag> tags) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert list of objects to list of JSON strings
    List<String> jsonList = tags
        .map((tag) => jsonEncode(tag.toJson()))
        .toList();
    await prefs.setStringList(_tagsKey, jsonList);
  }

  static Future<List<TrackerTag>> loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? jsonList = prefs.getStringList(_tagsKey);

    if (jsonList == null) return [];
    return jsonList
        .map((item) => TrackerTag.fromJson(jsonDecode(item)))
        .toList();
  }
}
