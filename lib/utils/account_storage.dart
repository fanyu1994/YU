import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 最近登录账号存储（用户名 + 密码）
class AccountStorage {
  static const String _key = 'recent-accounts';
  static const int _maxCount = 5;

  /// 读取最近登录的账号列表
  static Future<List<Map<String, String>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    final accounts = <Map<String, String>>[];
    for (final e in list) {
      if (e is Map) {
        accounts.add(Map<String, String>.from(e));
      } else if (e is String) {
        // 兼容旧格式（仅存用户名）
        accounts.add({'username': e, 'password': ''});
      }
    }
    return accounts;
  }

  /// 保存账号（去重、移到最前、最多保留 _maxCount 条）
  static Future<void> saveAccount(String username, String password) async {
    if (username.isEmpty) return;
    final accounts = await getAccounts();
    accounts.removeWhere((e) => e['username'] == username);
    accounts.insert(0, {'username': username, 'password': password});
    if (accounts.length > _maxCount) {
      accounts.removeRange(_maxCount, accounts.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(accounts));
  }

  /// 清除所有记录
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
