import 'package:yu/network/api_client.dart';
import 'package:yu/config/env.dart';

// api接口

class LoginApi {
  static const String loginUrl = '/oauth2/token?grant_type=password';
  static const String registerUrl = '/register';
  static const String refreshTokenUrl = '/refresh';
  static const String logoutUrl = '/logout';

  static const String baseUrl = Env.baseUrl; // 后端接口地址

  // 登录接口
  static Future<dynamic> login(String username, String password) async {
    return await ApiClient.instance.post(
      baseUrl + loginUrl,
      data: {'username': username, 'password': password},
    );
  }

  // 注册接口
  static Future<void> register(String username, String password) async {
    await ApiClient.instance.post(
      baseUrl + registerUrl,
      data: {'username': username, 'password': password},
    );
  }

  // 刷新 token 接口
  static Future<void> refreshToken() async {
    await ApiClient.instance.post(baseUrl + refreshTokenUrl);
  }

  // 退出登录接口
  static Future<void> logout() async {
    await ApiClient.instance.post(baseUrl + logoutUrl);
  }
}
