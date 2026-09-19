import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/screens/admin/dso_dashboard_screen.dart';
import 'package:pds_demandsync/services/api_service.dart';
import 'package:pds_demandsync/models/admin_model.dart';
import 'package:pds_demandsync/models/beneficiary_model.dart';

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
      fpsList: [
        AdminFpsRow(
          fpsId: 'FPS-KA-BAG-0001',
          name: 'Fair Price Shop 1 (Bagalur)',
          district: 'Bengaluru Urban',
          latitude: 12.9716,
          longitude: 77.5946,
          capacityKg: 15000.0,
          registeredBeneficiaries: 350,
          historicalDemandKg: 12000.0,
          declaredIntentKg: 14200.0,
          intentShiftKg: 2200.0,
          intentShiftPct: 18.3,
          inventoryKg: 1200.0,
          inventoryUtilizationPct: 8.0,
          forecastKg: 14200.0,
          recommendedDispatchKg: 13000.0,
          confidenceScore: 0.95,
          riskLevel: 'LOW',
          riskReason: 'Optimal buffer level',
          status: 'Planning',
        )
      ],
      workflowStatus: 'FORECASTED',
      depotAvailableStockMt: 850.0,
    );
  }

  Future<Map<String, dynamic>> fetchWorkflowState({String cycleId = '2026-09'}) async {
    return {
      'cycle_id': cycleId,
      'current_state': 'FORECASTED',
      'active_stage_index': 0,
      'is_terminal': false,
    };
  }

  @override
  Future<List<FpsShop>> fetchFpsList() async {
    return [
      FpsShop(
        id: 1,
        fpsId: 'FPS-KA-BAG-0001',
        name: 'Fair Price Shop 1 (Bagalur)',
        district: 'Bengaluru Urban',
        latitude: 12.9716,
        longitude: 77.5946,
        capacityKg: 15000.0,
        status: 'ACTIVE',
      )
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchDsoAllocationPlan({String cycleId = '2026-09'}) async {
    return {
      'cycle_id': cycleId,
      'central_depot_available_stock_mt': 850.0,
      'total_fps_inventory_mt': 24.5,
      'total_validated_demand_mt': 276.7,
      'proposed_allocation_mt': 276.7,
      'statutory_reserve_buffer_mt': 573.3,
      'allocations': [
        {
          'fps_id': 'FPS-KA-BAG-0001',
          'fps_name': 'Fair Price Shop 1 (Bagalur)',
          'commodity': 'Rice',
          'validated_demand_kg': 14200.0,
          'existing_inventory_kg': 1200.0,
          'proposed_allocation_kg': 13000.0,
          'allocated_quantity_kg': 13000.0,
          'central_depot_stock_mt': 850.0,
        }
      ]
    };
  }

  @override
  Future<Map<String, dynamic>> fetchDsoSupplyRoutes({String cycleId = '2026-09'}) async {
    return {
      'cycle_id': cycleId,
      'routes': [
        {
          'route_id': 'RT-GDN-KA-0001-0001',
          'truck_id': 'TRK-KA-0032',
          'corridor': 'East Corridor / IT Belt',
          'vehicle_type': '10-Ton Multi-Axle Carrier',
          'payload_capacity_kg': 10000.0,
          'total_quantity_kg': 2850.0,
          'driver_name': 'Venkatesh Gowda',
          'stops': [
            {
              'sequence': 1,
              'fps_id': 'FPS-KA-BAG-0001',
              'fps_name': 'Fair Price Shop 1 (Bagalur)',
              'commodity': 'Rice',
              'quantity_kg': 2850.0,
              'distance_km': 10.5,
              'eta': '09:45 AM',
            }
          ]
        }
      ]
    };
  }

  @override
  Future<Map<String, dynamic>> fetchDsoReconciliation({String cycleId = '2026-09'}) async {
    return {
      'cycle_id': cycleId,
      'allocated_mt': 276.7,
      'dispatched_mt': 276.7,
      'received_mt': 276.7,
      'distributed_mt': 271.4,
      'remaining_fps_buffer_mt': 5.3,
      'unexplained_variance_kg': 0.0,
      'reconciliation_status': 'CLEAN_CLOSED_LOOP',
      'variance_notes': 'Clean closed-loop. Zero unexplained variance across supply chain.',
    };
  }

  @override
  Future<Map<String, dynamic>> fetchWorkflowClosureChecklist({String cycleId = '2026-09'}) async {
    return {
      'cycle_id': cycleId,
      'is_ready_for_closure': false,
      'blocking_reasons': ['Delivery operations not yet complete in field.'],
      'checklist': {
        'demand_validated': true,
        'allocation_approved': false,
        'routes_optimized': false,
        'dispatch_authorized': false,
        'deliveries_complete': false,
        'inspections_reviewed': false,
        'reconciliation_complete': false,
      }
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGovernanceEvents({String? cycleId, int limit = 50}) async {
    return [
      {
        'event_type': 'DEMAND_VALIDATED',
        'actor_name': 'District Supply Officer',
        'actor_role': 'DSO',
        'notes': 'Aggregated citizen intent validated and sealed.',
        'created_at': '2026-09-20 04:00:00',
      }
    ];
  }

  @override
  Future<ForecastEvaluationData> fetchForecastEvaluation({String cycleId = '2026-09'}) async {
    return ForecastEvaluationData(
      status: 'success',
      workflowStatus: 'FORECAST_EVALUATED',
      cycleId: cycleId,
      recordsEvaluatedCount: 20,
      totalForecastQuantityKg: 276700.0,
      totalActualQuantityKg: 271400.0,
      totalAbsoluteErrorKg: 708.6,
      maeKg: 35.43,
      mapePct: 2.48,
      overallAccuracyPct: 97.52,
      riceMapePct: 2.31,
      wheatMapePct: 2.65,
      commodityBreakdown: {},
      fpsEvaluations: [],
      message: 'High accuracy evaluation verified.',
    );
  }
}

void main() {
  testWidgets('DSO Command Workflow: Renders top command bar, workflow navigation rail, and operational stages', (tester) async {
    final mockApi = MockDsoApiService();

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DsoDashboardScreen(
          apiService: mockApi,
          username: 'dso_user',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Top Command Bar
    expect(find.text('PDS DEMANDSYNC'), findsOneWidget);
    expect(find.text('DISTRICT SUPPLY COMMAND • BENGALURU URBAN'), findsOneWidget);
    expect(find.textContaining('CYCLE: 2026-09'), findsOneWidget);
    expect(find.text('WAL ACTIVE • INTEGRITY VERIFIED'), findsOneWidget);
    expect(find.text('DECISION TRACE'), findsOneWidget);

    // 2. Verify Workflow Navigation Rail (All 7 stages)
    expect(find.text('01 MONITOR'), findsWidgets);
    expect(find.text('02 VALIDATE'), findsWidgets);
    expect(find.text('03 ALLOCATE'), findsWidgets);
    expect(find.text('04 OPTIMIZE'), findsWidgets);
    expect(find.text('05 DISPATCH'), findsWidgets);
    expect(find.text('06 DELIVERY'), findsWidgets);
    expect(find.text('07 EVALUATE'), findsWidgets);

    // 3. Verify Stage 01 Operational Metrics and Formulas
    expect(find.text('WHAT REQUIRES ATTENTION'), findsOneWidget);
    expect(find.text('DEMAND OVERVIEW & STATUTORY FORMULAS'), findsOneWidget);
    expect(find.textContaining('Intent'), findsWidgets);
    expect(find.textContaining('Forecast'), findsWidgets);

    // 4. Verify Decision Trace Drawer
    final decisionTraceBtn = find.text('DECISION TRACE');
    await tester.ensureVisible(decisionTraceBtn);
    await tester.pumpAndSettle();
    await tester.tap(decisionTraceBtn);
    await tester.pumpAndSettle();
    expect(find.text('GOVERNANCE DECISION TRACE'), findsOneWidget);
    expect(find.text('Aggregated citizen intent validated and sealed.'), findsOneWidget);
  });
}
