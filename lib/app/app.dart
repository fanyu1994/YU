import 'package:flutter/material.dart';
import 'routes.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YU One',
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
      theme: ThemeData.light(useMaterial3: true),
    );
  }
}
