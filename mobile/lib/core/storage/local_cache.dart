import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin JSON cache over SharedPreferences, used to show the last-known data
/// instantly on cold start while a live refresh happens in the background
/// (stale-while-revalidate), and to keep working read-only when offline.
class LocalCache {
  LocalCache(this._prefs);

  static const _prefix = 'cache.';

  final SharedPreferences _prefs;

  Future<void> writeList(String key, List<Map<String, dynamic>> items) {
    return _prefs.setString('$_prefix$key', jsonEncode(items));
  }

  List<Map<String, dynamic>>? readList(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) {
    return _prefs.setString('$_prefix$key', jsonEncode(value));
  }

  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
