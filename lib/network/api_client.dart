import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yu/config/env.dart';

import '../utils/token_storage.dart';
import 'api_exception.dart';
import 'api_response.dart';

/// HTTP 网络请求客户端（单例）
///
/// 职责：
/// - 统一 baseUrl、超时时间
/// - 自动从本地读取 token 注入 Authorization 头
/// - 自动解包 {code, message, data}，业务层直接拿到 data
/// - 把所有错误统一转换成 [ApiException]
///
/// 用法：
/// ```dart
/// final data = await ApiClient.instance.get<Map<String, dynamic>>('/user/info');
/// final list = await ApiClient.instance.post<List>('/list', data: {'page': 1});
/// ```
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  static final ApiClient instance = ApiClient._internal();

  /// 接口根地址，接入真实后端时替换这里
  static const String baseUrl = Env.baseUrl;

  late final Dio _dio;

  /// 暴露原生 Dio，用于需要自定义 Options / FormData 等特殊场景
  Dio get dio => _dio;

  // ---------------------------------------------------------------------------
  // 请求方法
  // ---------------------------------------------------------------------------

  /// GET 请求，返回解包后的 data
  Future<T?> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
        options: options,
      ),
    );
  }

  /// POST 请求，返回解包后的 data
  Future<T?> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
        options: options,
      ),
    );
  }

  /// PUT 请求，返回解包后的 data
  Future<T?> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
        options: options,
      ),
    );
  }

  /// DELETE 请求，返回解包后的 data
  Future<T?> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
        options: options,
      ),
    );
  }

  /// PATCH 请求，返回解包后的 data
  Future<T?> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
        options: options,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 内部实现
  // ---------------------------------------------------------------------------

  /// 统一执行请求：解包响应 + 统一异常
  Future<T?> _request<T>(Future<Response<dynamic>> Function() send) async {
    try {
      final response = await send();
      return ApiResponse.fromJson(response.data).unwrap() as T?;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      // 拦截器中已转换过的异常直接抛出
      final error = e.error;
      if (error is ApiException) throw error;
      throw _mapDioException(e);
    } catch (e) {
      throw ApiException(message: '数据解析失败', error: e);
    }
  }

  /// 请求前注入 Authorization
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      // jxd业务
      options.headers['client-id'] = 'hussar-base';
      options.headers['dev-user'] = 'testEnv87';
      // jxd业务结束
    } catch (e) {
      debugPrint('读取本地 token 失败: $e');
    }
    handler.next(options);
  }

  /// 把 DioException 转成 ApiException，交给 _request 统一处理
  void _onError(DioException e, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: _mapDioException(e),
      ),
    );
  }

  /// 网络层错误映射为统一异常
  ApiException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(message: '请求超时，请检查网络后重试', error: e);
      case DioExceptionType.connectionError:
        return ApiException(message: '网络连接失败，请检查网络设置', error: e);
      case DioExceptionType.badCertificate:
        return ApiException(message: '证书校验失败', error: e);
      case DioExceptionType.cancel:
        return ApiException(message: '请求已取消', error: e);
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        return ApiException(
          message: _messageByStatusCode(statusCode),
          statusCode: statusCode,
          error: e,
        );
      case DioExceptionType.unknown:
        return ApiException(message: '网络异常，请稍后重试', error: e);
    }
  }

  String _messageByStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数有误';
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有访问权限';
      case 404:
        return '请求的资源不存在';
      case 405:
        return '请求方法不被允许';
      case 408:
        return '请求超时';
      case 500:
        return '服务器内部错误';
      case 502:
        return '网关错误';
      case 503:
        return '服务暂不可用';
      case 504:
        return '网关超时';
      default:
        return statusCode == null ? '请求失败' : '请求失败（$statusCode）';
    }
  }
}