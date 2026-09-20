import 'package:flutter/material.dart';
import '../pages/home/home_page.dart'; 
import '../pages/login/login_page.dart';
import '../pages/register/register_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';

  static final Map<String, WidgetBuilder> routes = {
    home: (context) => const HomePage(),
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
  };
}
