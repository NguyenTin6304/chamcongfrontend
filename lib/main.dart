import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'core/layout/app_scaffold.dart';
import 'core/services/notification_store.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_colors.dart';
import 'features/admin/presentation/shell/admin_shell_page.dart';
import 'features/auth/presentation/forgot_password_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/reset_password_page.dart';
import 'features/attendance/presentation/employee_exceptions_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initializeFirebase();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    PushNotificationService.setupForegroundHandler(NotificationStore.add);
  }

  static const Set<String> _supportedPaths = {
    '/login',
    '/forgot-password',
    '/reset-password',
    '/admin',
    '/admin/attendance',
    '/admin/employees',
    '/admin/groups',
    '/admin/geofences',
    '/admin/reports',
    '/admin/exceptions',
    '/admin/settings',
    '/home',
    '/home/exceptions',
    '/history',
    '/profile',
  };

  String _extractEmailArg(RouteSettings settings) {
    final args = settings.arguments;
    if (args is Map) {
      final value = args['email'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

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
      case '/admin':
        page = AdminShellPage(
          email: _extractEmailArg(settings),
          initialSection: 'dashboard',
        );
        break;
      case '/admin/attendance':
        page = AdminShellPage(
          email: _extractEmailArg(settings),
          initialSection: 'logs',
        );
        break;
      case '/admin/employees':
        page = AdminShellPage(
          email: _extractEmailArg(settings),
          initialSection: 'employees',
        );
        break;
      case '/admin/groups':
        page = AdminShellPage(
          email: _extractEmailArg(settings),
          initialSection: 'groups',
        );
        break;
      case '/admin/geofences':
        page = AdminShellPage(
          email: _extractEmailArg(settings),
          initialSection: 'geofences',
        );
        break;
      case '/admin/reports':
        page = AdminShellPage(
          email: _extractEmailArg(settings),
          initialSection: 'reports',
        );
        break;
      case '/admin/exceptions':
        page = AdminShellPage(
          email: _extractEmailArg(settings),
          initialSection: 'exceptions',
        );
        break;
      case '/admin/settings':
        page = AdminShellPage(
          email: _extractEmailArg(settings),
          initialSection: 'settings',
        );
        break;
      case '/home':
        page = AppScaffold(initialIndex: 0, email: _extractEmailArg(settings));
        break;
      case '/home/exceptions':
        page = const EmployeeExceptionsScreen();
        break;
      case '/history':
        page = const AppScaffold(initialIndex: 1);
        break;
      case '/profile':
        page = const AppScaffold(initialIndex: 2);
        break;
      default:
        page = const LoginPage();
        break;
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  List<Route<dynamic>> _buildInitialRoutes(String initialRouteName) {
    return <Route<dynamic>>[_buildRoute(RouteSettings(name: initialRouteName))];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chấm Công App',
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.bgPage,
        useMaterial3: true,
      ),
      initialRoute: _resolveInitialRouteFromUrl(),
      onGenerateInitialRoutes: _buildInitialRoutes,
      onGenerateRoute: _buildRoute,
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const LoginPage(),
        settings: settings,
      ),
    );
  }
}
