import 'package:flutter/material.dart';
import 'home/home_page.dart';
import 'login/login_page.dart';
import 'register/register_page.dart';
import 'y/y_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String y = '/y';

  static final Map<String, WidgetBuilder> routes = {
    home: (context) => const HomePage(),
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
    y: (context) => const YPage(),
  };
}
