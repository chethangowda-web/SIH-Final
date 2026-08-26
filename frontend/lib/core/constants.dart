import 'package:flutter/material.dart';

class AppConstants {
  // App Branding
  static const String appName = 'PDS Pre-Dispatch Intelligence & Alert System';
  static const String appSubtitle =
      'Interoperable Pre-Dispatch Decision Intelligence: Forecast → Decide → Validate → Optimize → Lock → Notify → Feedback';
  static const String appTagline = 'Smart India Hackathon 2026 • Demo V1';
  static const String demoNotice =
      'DEMO PROTOTYPE ONLY — 100% Synthetic Data & Simulated Telemetry';

  // API Endpoints
  // In Flutter Web on localhost, 127.0.0.1:8000 is accessible
  static const String apiBaseUrl = 'http://127.0.0.1:8000/api';
  static const String healthEndpoint = '$apiBaseUrl/health';

  // GovTech Color Palette
  static const Color primaryNavy = Color(0xFF0A2540); // Deep Sovereign Navy
  static const Color secondaryNavy = Color(0xFF1E3A8A); // Royal PDS Blue
  static const Color accentBlue = Color(0xFF2563EB); // Modern Link / Focus Blue
  static const Color accentAmber = Color(0xFFD97706); // Warm Govt Saffron / Alert
  static const Color backgroundLight = Color(0xFFF8FAFC); // Clean Canvas Neutral
  static const Color bgLight = backgroundLight; // Alias for convenience
  static const Color cardSurface = Colors.white; // Pure White Card Background
  static const Color borderLight = Color(0xFFE2E8F0); // Subtle GovTech Border
  static const Color cardBorder = borderLight; // Alias for convenience
  static const Color textPrimary = Color(0xFF0F172A); // High Contrast Dark
  static const Color textSecondary = Color(0xFF475569); // Muted Slate
  static const Color textTertiary = Color(0xFF94A3B8); // Light Slate
  static const Color successGreen = Color(0xFF16A34A); // Verified / Connected
  static const Color dangerRed = Color(0xFFDC2626); // Error / Stockout
  static const Color purpleAccent = Color(0xFF673AB7); // Gatepass Purple
  static const Color tealAccent = Color(0xFF00897B); // WhatsApp Teal

  // 9-Stage Pre-Dispatch Decision Pipeline
  static const List<Map<String, String>> workflowSteps = [
    {
      'num': '1',
      'title': 'DATA SOURCES',
      'desc': 'FPS inventory, historical offtake & beneficiary signals'
    },
    {
      'num': '2',
      'title': 'DEMAND FORECAST',
      'desc': 'D_hat = (1-w*C)*H + (w*C)*I explainable model'
    },
    {
      'num': '3',
      'title': 'DISPATCH DECISION',
      'desc': 'Rec. Dispatch = D_hat - Stock + Safety Buffer'
    },
    {
      'num': '4',
      'title': 'CONSTRAINT VALIDATION',
      'desc': '6 rules: Storage, Payload, Depot, Safety, Quota, Availability'
    },
    {
      'num': '5',
      'title': 'ROUTE OPTIMIZATION',
      'desc': 'Corridor sequencing, distance km & fuel cost modeling'
    },
    {
      'num': '6',
      'title': 'MANIFEST LOCK',
      'desc': 'Immutable locked manifest with SHA-256 digital audit stamp'
    },
    {
      'num': '7',
      'title': 'DIGITAL GATEPASS',
      'desc': '5-stage physical handshake: Auth -> Bay -> Loading -> Exit'
    },
    {
      'num': '8',
      'title': 'READINESS ALERTS',
      'desc': 'Simulated WhatsApp/SMS to FPS Dealers & Beneficiaries'
    },
    {
      'num': '9',
      'title': 'FEEDBACK LOOP',
      'desc': 'ePoS offtake comparison, error evaluation & ML calibration'
    },
  ];
}
