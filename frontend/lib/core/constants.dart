import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  // App Branding
  static const String appName = 'PDS DemandSync';
  static const String appSubtitle =
      'Bengaluru Urban District • Public Distribution System Operations';
  static const String appTagline = 'Govt. of Karnataka • Food & Civil Supplies';
  static const String demoNotice =
      'Govt. of Karnataka • Bengaluru Urban PDS Operations';

  // API Endpoints
  static String get apiBaseUrl {
    if (kIsWeb) {
      return '${Uri.base.origin}/api';
    }
    return 'http://127.0.0.1:8000/api';
  }
  static String get healthEndpoint => '$apiBaseUrl/health';

  // Modern Government Digital Infrastructure Color Palette
  static const Color primaryNavy = Color(0xFF0B2942); // Deep Government Navy
  static const Color secondaryNavy = Color(0xFF1E3A8A); // Royal PDS Blue
  static const Color accentBlue = Color(0xFF2563EB); // Modern Link / Focus Royal Blue
  static const Color accentAmber = Color(0xFFD97706); // Warm Amber / Alert
  static const Color backgroundLight = Color(0xFFF6F8FB); // Very light blue-gray neutral
  static const Color bgLight = backgroundLight; // Alias
  static const Color cardSurface = Color(0xFFFFFFFF); // Pure White Surface
  static const Color borderLight = Color(0xFFD9E1EA); // 1px Subtle GovTech Border
  static const Color cardBorder = borderLight; // Alias
  static const Color textPrimary = Color(0xFF102A43); // High Contrast Dark Slate Navy
  static const Color textSecondary = Color(0xFF52667A); // Muted Blue-Grey Body
  static const Color textTertiary = Color(0xFF718096); // Muted Slate Caption
  static const Color successGreen = Color(0xFF16A34A); // Verified / Connected Green
  static const Color dangerRed = Color(0xFFDC2626); // Error / Risk Red
  static const Color infoCyan = Color(0xFF0891B2); // Information Cyan
  static const Color purpleAccent = Color(0xFF7C3AED); // AI / Simulation Accent
  static const Color tealAccent = Color(0xFF0D9488); // Telemetry Teal

  // Standard Spacing System (8px Grid)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space18 = 18.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;

  // Standard Border Radius System
  static const double radiusSmall = 6.0;
  static const double radiusMedium = 10.0;
  static const double radiusLarge = 14.0;
  static const double radiusPill = 999.0;

  // 8-Stage Pre-Dispatch Decision Pipeline (Standard Enterprise Flow)
  static const List<Map<String, String>> workflowSteps = [
    {
      'num': '01',
      'title': 'Forecast',
      'desc': 'D̂ = (1-w*C)*H + (w*C)*I demand forecast'
    },
    {
      'num': '02',
      'title': 'Lock Forecast',
      'desc': 'Choice window close & demand baseline lock'
    },
    {
      'num': '03',
      'title': 'Constraints',
      'desc': 'Statutory floor, payload, depot & capacity validation'
    },
    {
      'num': '04',
      'title': 'Optimization',
      'desc': 'Multi-stop TSP routing, mileage & fuel cost modeling'
    },
    {
      'num': '05',
      'title': 'Manifest',
      'desc': 'Immutable locked manifest with SHA-256 digital seal'
    },
    {
      'num': '06',
      'title': 'Gatepass',
      'desc': '4-stage physical handshake: Auth -> Bay -> Loading -> Exit'
    },
    {
      'num': '07',
      'title': 'Dispatch',
      'desc': 'Godown physical truck dispatch & live tracking'
    },
    {
      'num': '08',
      'title': 'Evaluation',
      'desc': 'ePoS offtake comparison, error evaluation & ML calibration'
    },
  ];
}
