import 'package:dio/dio.dart';
import 'package:yu/network/api_client.dart';
import 'package:yu/config/env.dart';

// api接口

class LoginApi {
  static const String loginUrl = '/oauth2/token';
  static const String registerUrl = '/register';
  static const String refreshTokenUrl = '/refresh';
  static const String logoutUrl = '/logout';

  static const String baseUrl = Env.baseUrl; // 后端接口地址

  /// 登录接口（OAuth2 password grant）
  ///
  /// 与 H5 端保持一致：
  /// - grant_type 放 URL query
  /// - body 用 application/x-www-form-urlencoded
  /// - password 传加密后的密文
  static Future<dynamic> login(
    String username,
    String encryptedPassword, {
    String code = '',
    String randomStr = 'blockPuzzle',
    String isIndex = 'mobile',
    String kaptcha = '',
    String? tenantId,
    String? checkCode,
    String? uniqueId,
  }) async {
    final url = '$baseUrl$loginUrl?grant_type=password';

    final headers = <String, dynamic>{
      'Tenant-Id': tenantId ?? '',
      'noEncrypt': 'true',
      'x-requested-with': 'AxiosHttpRequest',
      'checkCode': checkCode ?? '',
      'uniqueId': uniqueId ?? '',
    };

    return await ApiClient.instance.postRaw(
      url,
      data: {
        'username': username,
        'password': encryptedPassword,
        'code': code,
        'randomStr': randomStr,
        'isIndex': isIndex,
        'kaptcha': kaptcha,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: headers,
      ),
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
