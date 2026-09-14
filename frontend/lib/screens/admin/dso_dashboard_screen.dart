import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'admin_dashboard_screen.dart';

class DsoDashboardScreen extends StatelessWidget {
  final ApiService? apiService;
  final String? username;

  const DsoDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    return AdminDashboardScreen(
      apiService: apiService,
      userRole: 'DSO',
      username: username ?? 'dso_user',
    );
  }
}
