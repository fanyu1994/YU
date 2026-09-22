import 'package:yu/config/env.dart';
import 'package:yu/network/api_client.dart';
import 'package:flutter/material.dart';

class YApi {
  static const String applicationGroupQueryListByPermission =
      '/mobile/application/group/queryListByPermission';
  static const String backendUrl = Env.baseUrl;

  /// 获取 YU 项目列表
  static Future<List<Map<String, dynamic>>> getApplications() async {
    final response = await ApiClient.instance.get(
      '$backendUrl$applicationGroupQueryListByPermission',
    );
    final list = response as List;
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
