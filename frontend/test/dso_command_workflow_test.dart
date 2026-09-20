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

  @override
  Future<Map<String, dynamic>> fetchWorkflowStatus({String cycleId = '2026-09'}) async {
    return {
      'cycle_id': cycleId,
      'current_state': 'FORECASTED',
      'active_stage_index': 0,
      'blocking_conditions': [],
      'is_terminal': false,
    };
  }

  @override
  Future<List<FpsShop>> fetchFPSList() async {
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
      'available_depot_stock_mt': 850.0,
      'total_existing_fps_stock_mt': 24.5,
      'total_validated_demand_mt': 276.7,
      'proposed_allocation_mt': 276.7,
      'statutory_reserve_buffer_mt': 573.3,
      'items': [
        {
          'fps_id': 'FPS-KA-BAG-0001',
          'fps_name': 'Fair Price Shop 1 (Bagalur)',
          'commodity': 'Rice',
          'validated_requirement_kg': 14200.0,
          'existing_stock_kg': 1200.0,
          'net_requirement_kg': 13000.0,
          'proposed_allocation_kg': 13000.0,
          'priority': 'NORMAL',
          'is_overridden': false,
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
  Future<DispatchManifestData> fetchDispatchManifest({String cycleId = '2026-09'}) async {
    return DispatchManifestData(
      status: 'success',
      workflowStatus: 'MANIFEST_GENERATED',
      cycleId: cycleId,
      totalDispatchKg: 2850.0,
      totalRiceDispatchKg: 1750.0,
      totalWheatDispatchKg: 1100.0,
      totalFpsCount: 1,
      totalVehiclesCount: 1,
      vehicles: [],
      records: [
        DispatchRecord(
          id: 101,
          fpsId: 'FPS-KA-BAG-0001',
          fpsName: 'Fair Price Shop 1 (Bagalur)',
          cycleId: cycleId,
          commodity: 'Rice',
          quantityKg: 2850.0,
          sourceGodown: 'FCI Central Godown (Hebbal)',
          demoTruckId: 'TRK-KA-0032',
          status: 'SEALED',
          createdAt: '2026-09-20 08:30:00',
        ),
      ],
      message: 'Manifests loaded successfully',
    );
  }

  @override
  Future<List<DigitalGatepass>> fetchAllGatepasses({String cycleId = '2026-09'}) async {
    return [
      DigitalGatepass(
        gatepassId: 'GP-2026-101',
        cycleId: cycleId,
        manifestId: '101',
        truckId: 'TRK-KA-0032',
        corridor: 'East Corridor / IT Belt',
        status: 'VALID',
        sourceDepotId: 'DEPOT-01',
        depotName: 'FCI Central Godown',
        depotLocation: 'Hebbal, Bengaluru',
        loadingBay: 'Bay 2',
        driverName: 'Venkatesh Gowda',
        driverPhone: '+91 98765 43210',
        securityToken: 'SEC-TOKEN-8819',
        approvingOfficer: 'DSO Officer',
        totalRiceKg: 1750.0,
        totalWheatKg: 1100.0,
        totalPayloadKg: 2850.0,
        deliveryStops: [],
        eventTimeline: [],
        qrVerificationString: 'VERIFIED-QR-2026-09',
        demoDisclaimer: 'Official pass',
      ),
    ];
  }

  @override
  Future<List<TruckRouteTracking>> fetchActiveTruckTrackings({String cycleId = '2026-09'}) async {
    return [
      TruckRouteTracking(
        truckId: 'TRK-KA-0032',
        driverName: 'Venkatesh Gowda',
        gatepassId: 'GP-2026-101',
        originGodown: 'FCI Central Godown (Hebbal)',
        destinationFps: 'FPS-KA-BAG-0001',
        assignedRoute: 'East Corridor / IT Belt',
        currentStatus: 'IN_TRANSIT',
        currentCheckpoint: 'Hebbal Flyover',
        nextCheckpoint: 'Bagalur Main Road',
        totalDistanceKm: 18.5,
        distanceTravelledKm: 8.0,
        distanceRemainingKm: 10.5,
        eta: '09:45 AM',
        lastLocation: 'Hebbal Flyover Junction (13.0358° N, 77.5970° E)',
        lastUpdated: 'Just now',
        delayMinutes: 0,
        delayStatus: 'ON_TIME',
        routeDeviationStatus: 'NORMAL',
        checkpoints: [],
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchFpsInspections({String? fpsId}) async {
    return {
      'orders': [
        {
          'order_id': 'DIR-2026-001',
          'fps_id': 'FPS-KA-BAG-0001',
          'priority': 'HIGH',
          'reason': 'DSO Surprise Stock Audit & Physical Inventory Verification',
          'status': 'ASSIGNED',
        }
      ],
      'completed_inspections': [
        {
          'inspection_id': 'INSP-2026-0081',
          'fps_id': 'FPS-KA-BAG-0001',
          'inspector_id': 'INSP-OFFICER-04',
          'inspection_type': 'SURPRISE',
          'compliance_score': 98.5,
          'remarks': 'Physical grain bags count strictly matched e-PoS ledger balance.',
          'created_at': '2026-09-20 11:20:00',
        }
      ],
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
  testWidgets('DSO Command Workflow: Renders top command bar, horizontal workflow stepper, and primary decision area', (tester) async {
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
    expect(find.text('PDS DemandSync'), findsOneWidget);
    expect(find.text('DSO Command Center • Bengaluru Urban'), findsOneWidget);
    expect(find.textContaining('Current cycle: 2026-09'), findsOneWidget);
    expect(find.text('WAL ACTIVE • INTEGRITY VERIFIED'), findsOneWidget);
    expect(find.text('DECISION TRACE'), findsOneWidget);

    // 2. Verify Horizontal Workflow Stepper (All 7 workflow stages)
    expect(find.text('DEMAND'), findsWidgets);
    expect(find.text('VALIDATE'), findsWidgets);
    expect(find.text('ALLOCATE'), findsWidgets);
    expect(find.text('OPTIMIZE'), findsWidgets);
    expect(find.text('DISPATCH'), findsWidgets);
    expect(find.text('DELIVERY'), findsWidgets);
    expect(find.text('EVALUATE'), findsWidgets);

    // 3. Verify Primary Decision Area ("WHAT NEEDS YOUR DECISION?")
    expect(find.text('WHAT NEEDS YOUR DECISION?'), findsOneWidget);
    expect(find.text('REVIEW & VALIDATE DEMAND'), findsWidgets);

    // 4. Verify Stage 01 Operational Metrics and Formulas
    expect(find.text('WHAT REQUIRES ATTENTION'), findsOneWidget);
    expect(find.text('DEMAND OVERVIEW & STATUTORY FORMULAS'), findsOneWidget);
    expect(find.textContaining('Intent − Forecast = Difference'), findsOneWidget);
    expect(find.textContaining('Forecast − Baseline = Difference'), findsOneWidget);

    // 5. Verify Decision Trace Drawer
    final decisionTraceBtn = find.text('DECISION TRACE');
    await tester.ensureVisible(decisionTraceBtn);
    await tester.pumpAndSettle();
    await tester.tap(decisionTraceBtn);
    await tester.pumpAndSettle();
    expect(find.text('GOVERNANCE DECISION TRACE'), findsOneWidget);
    expect(find.text('Aggregated citizen intent validated and sealed.'), findsOneWidget);
  });
}
