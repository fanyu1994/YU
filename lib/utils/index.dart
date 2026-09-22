import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class Utils {
  Future<void> debugPrintAllStorage() async {
    debugPrint('=== 所有存储 ===');
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      debugPrint('$key = ${prefs.getString(key)}');
    }
  }
}
