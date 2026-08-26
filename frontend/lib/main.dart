import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'screens/beneficiary/demo_login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdsDemandSyncApp());
}

class PdsDemandSyncApp extends StatelessWidget {
  const PdsDemandSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
