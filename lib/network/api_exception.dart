/// 统一的接口异常
///
/// 所有网络层错误（业务码异常、HTTP 错误、超时、解析失败）都会被转换成
/// [ApiException]，业务层只需 catch 这一种类型。
class ApiException implements Exception {
  /// 业务码（后端返回的 code），网络层错误时为 null
  final int? code;

  /// 面向用户的错误提示
  final String message;

  /// HTTP 状态码，未拿到响应时为 null
  final int? statusCode;

  /// 原始错误对象，便于排查
  final Object? error;

  const ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.error,
  });

  /// 是否为鉴权失败（登录态失效）
  bool get isUnauthorized => statusCode == 401 || code == 401;

  @override
  String toString() =>
      'ApiException(code: $code, statusCode: $statusCode, message: $message)';
}