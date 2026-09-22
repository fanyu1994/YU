import 'package:shared_preferences/shared_preferences.dart';

/// 本地 token 存储
class TokenStorage {
  static const String _key = 'access-token';

  /// 读取本地 token，未登录时返回 null
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// 保存 token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  /// 清除 token（退出登录）
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
