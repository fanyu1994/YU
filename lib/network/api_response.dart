import 'api_exception.dart';

/// 后端统一响应结构：{ "code": 0, "message": "ok", "data": {...} }
class ApiResponse<T> {
  /// 业务码
  final int code;

  /// 业务提示信息
  final String message;

  /// 业务数据
  final T? data;

  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  /// 业务成功的判定码，按后端约定修改
  static const int successCode = 10000;

  bool get isSuccess => code == successCode;

  /// 从原始 JSON 构建；非预期结构会直接抛出 [ApiException]
  factory ApiResponse.fromJson(dynamic raw) {
    if (raw is! Map) {
      throw ApiException(
        message: '响应数据格式异常',
        error: raw,
      );
    }

    final map = Map<String, dynamic>.from(raw);
    // code 可能被后端序列化成字符串，这里统一转成 int
    final rawCode = map['code'];
    final code = rawCode is int
        ? rawCode
        : int.tryParse('$rawCode') ?? -1;

    return ApiResponse(
      code: code,
      message: map['message']?.toString() ?? '',
      data: map['data'],
    );
  }

  /// 校验业务码，失败时抛出 [ApiException]，成功时返回解包后的 data
  T? unwrap() {
    if (!isSuccess) {
      throw ApiException(
        code: code,
        message: message.isEmpty ? '请求失败（$code）' : message,
      );
    }
    return data;
  }
}