import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'admin_dashboard_screen.dart';

class SystemAdminDashboardScreen extends StatelessWidget {
  final ApiService? apiService;
  final String? username;

  const SystemAdminDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    return AdminDashboardScreen(
      apiService: apiService,
      userRole: 'ADMIN',
      username: username ?? 'admin_user',
    );
  }
}
