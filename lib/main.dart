import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'features/auth/presentation/forgot_password_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/reset_password_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static const Set<String> _supportedPaths = {
    '/login',
    '/forgot-password',
    '/reset-password',
  };

  String _resolveInitialRouteFromUrl() {
    final fragment = Uri.base.fragment.trim();
    if (fragment.isNotEmpty) {
      final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
      final fragmentUri = Uri.tryParse(normalized);
      final fragmentPath = (fragmentUri?.path.isNotEmpty ?? false)
          ? fragmentUri!.path
          : normalized.split('?').first;
      if (_supportedPaths.contains(fragmentPath)) {
        return fragmentPath;
      }
    }

    final path = Uri.base.path.trim();
    if (_supportedPaths.contains(path)) {
      return path;
    }

    return '/login';
  }

  Route<dynamic> _buildRoute(RouteSettings settings) {
    final raw = settings.name ?? '/login';
    final routeName = raw.split('?').first;

    Widget page;
    switch (routeName) {
      case '/':
      case '/login':
        page = const LoginPage();
        break;
      case '/forgot-password':
        page = const ForgotPasswordPage();
        break;
      case '/reset-password':
        page = const ResetPasswordPage();
        break;
      default:
        page = const LoginPage();
        break;
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chấm Công App',
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
        scrollbars: true,
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: _resolveInitialRouteFromUrl(),
      onGenerateRoute: _buildRoute,
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const LoginPage(),
        settings: settings,
      ),
    );
  }
}
