import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/screens/dso/dso_command_center_screen.dart';
import 'package:pds_demandsync/services/api_service.dart';
import 'package:pds_demandsync/models/admin_model.dart';

class MockDsoApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    final role = (username == 'dso_user' ? 'DSO' : 'ADMIN');
    final data = {
      'access_token': 'mock-dso-token',
      'token_type': 'bearer',
      'role': role,
      'username': username,
      'expires_in': 36000,
    };
    authSession.setSession(
      token: data['access_token'] as String,
      username: username,
      role: role,
    );
    return data;
  }

  @override
  Future<AdminDashboardData> fetchAdminDashboard() async {
    return AdminDashboardData(
      district: 'Bengaluru Urban PDS Pilot',
      activeCycle: '2026-09',
      totalFps: 20,
      activeIntentsCount: 420,
      totalDeclaredIntentKg: 276700.0,
      totalHistoricalDemandKg: 260000.0,
      totalForecastDemandKg: 276700.0,
      totalRecommendedDispatchKg: 276700.0,
      averageConfidence: 0.96,
      forecastGeneratedCount: 20,
      highRiskFpsCount: 0,
      mediumRiskFpsCount: 2,
      lowRiskFpsCount: 18,
      exceptionCasesCount: 0,
      totalInventoryKg: 24500.0,
      totalCapacityKg: 500000.0,
      averageCapacityUtilizationPct: 4.9,
      riskDistribution: {'LOW': 18, 'MEDIUM': 2, 'HIGH': 0},
      historicalCyclesTrend: [],
      topIntentShiftFps: [],
      fpsList: [],
      workflowStatus: 'FORECASTED',
    );
  }
}

void main() {
  testWidgets('DSO Command Center Screen renders correctly with desktop shell', (WidgetTester tester) async {
    final mockApi = MockDsoApiService();
    await mockApi.login('dso_user', 'dso_pass');

    await tester.pumpWidget(
      MaterialApp(
        home: DsoCommandCenterScreen(
          apiService: mockApi,
          username: 'dso_user',
        ),
      ),
    );

    // Pump widget tree
    await tester.pump();

    // Verify brand title and headers
    expect(find.text('PDS DemandSync'), findsOneWidget);
    expect(find.text('DSO Command Center'), findsOneWidget);
    expect(find.text('District Supply Officer'), findsWidgets);
  });
}
