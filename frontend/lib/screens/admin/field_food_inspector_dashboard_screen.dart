import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../inspector/inspector_command_center_screen.dart';

/// Legacy Compatibility Forwarder for Field Food Inspector Dashboard Screen
/// Redirects directly to the rebuilt, authoritative InspectorCommandCenterScreen
class FieldFoodInspectorDashboardScreen extends StatelessWidget {
  final ApiService? apiService;
  final String? username;

  const FieldFoodInspectorDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveApiService = apiService ?? ApiService();
    return InspectorCommandCenterScreen(
      apiService: effectiveApiService,
      username: username,
    );
  }
}
