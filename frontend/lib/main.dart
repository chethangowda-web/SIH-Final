import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'screens/beneficiary/demo_login_screen.dart';
import 'services/auth_session.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup deterministic global 401 unauthorized redirect to login
  AuthSession.instance.onUnauthorized = () {
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const DemoLoginScreen(
          sessionExpiredMessage: 'Session expired or unauthorized. Please log in again.',
        ),
      ),
      (route) => false,
    );
  };

  runApp(const PdsDemandSyncApp());
}

class PdsDemandSyncApp extends StatelessWidget {
  const PdsDemandSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryNavy,
          primary: AppConstants.primaryNavy,
          secondary: AppConstants.secondaryNavy,
          surface: AppConstants.bgLight,
        ),
        scaffoldBackgroundColor: AppConstants.bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppConstants.cardBorder, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            elevation: 1,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const DemoLoginScreen(),
    );
  }
}
