class Env {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://172.23.2.87/hussarApi',// 测试环境
  );

  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://172.23.2.87:8992',// 测试环境
  );

  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static const bool debugApi = bool.fromEnvironment(
    'DEBUG_API',
    defaultValue: true,
  );
}
