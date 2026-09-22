import 'package:flutter/material.dart';
import 'package:yu/network/api_client.dart';
import 'routes.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YU One',
      navigatorKey: ApiClient.navigatorKey,
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
      theme: ThemeData.light(useMaterial3: true),
    );
  }
}
