import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../fps/fps_command_center_screen.dart';

/// Fair Price Shop Owner Portal Entry Screen
/// Delegates to the authoritative production-grade FpsCommandCenterScreen
class FpsOwnerDashboardScreen extends StatelessWidget {
  final ApiService? apiService;
  final String? username;

  const FpsOwnerDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveApiService = apiService ?? ApiService();
    return FpsCommandCenterScreen(
      apiService: effectiveApiService,
      initialFpsId: username?.startsWith('FPS-') == true ? username : null,
    );
  }
}
