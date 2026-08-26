import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/core/constants.dart';
import 'package:pds_demandsync/models/beneficiary_model.dart';
import 'package:pds_demandsync/models/admin_model.dart';
import 'package:pds_demandsync/models/scarcity_model.dart';
import 'package:pds_demandsync/screens/beneficiary/demo_login_screen.dart';
import 'package:pds_demandsync/screens/admin/admin_dashboard_screen.dart';
import 'package:pds_demandsync/screens/admin/scarcity_reconciliation_dialog.dart';
import 'package:pds_demandsync/services/api_service.dart';

class MockApiService extends ApiService {
  @override
  Future<List<Beneficiary>> fetchBeneficiaries({int limit = 100, int offset = 0, String? search}) async {
    return [
      Beneficiary(
        id: 1,
        pseudonymousBeneficiaryId: 'BEN-KA-0001',
        nameForDemo: 'Swathi B. (Demo)',
        registeredFpsId: 'FPS-KA-BLR-001',
        registeredFpsName: 'Malleshwaram Seva Kendra (Demo)',
        language: 'kn',
        status: 'ACTIVE',
      ),
    ];
  }

  @override
  Future<DepotBalanceModel> fetchScarcityDepotBalance(
      {String cycleId = '2026-09', String depotId = 'DEPOT-01', String commodity = 'Rice'}) async {
    return DepotBalanceModel(
      cycleId: cycleId,
      depotId: depotId,
      depotName: 'Bengaluru Central FCI Godown (Hebbal)',
      commodity: commodity,
      aggregateDemandKg: 5930.8,
      availableDepotStockKg: 25000.0,
      deficitKg: 0.0,
      deficitPercentage: 0.0,
      isScarcityCondition: false,
      scarcityCondition: 'NO_SCARCITY',
      statutoryFloorTotalKg: 3694.4,
      statutoryFloorStatus: 'STATUTORY_FLOORS_SATISFIED',
      isStatutoryFloorSatisfied: true,
      demoNotice: 'DEMO PROTOTYPE',
    );
  }

  @override
  Future<RiskPredictionResponseModel> predictStockoutRisk({
    String cycleId = '2026-09',
    String commodity = 'Rice',
    String? fpsId,
    List<String>? fpsIds,
    double? proposedAllocationKg,
  }) async {
    return RiskPredictionResponseModel(
      status: 'success',
      cycleId: cycleId,
      commodity: commodity,
      predictionsCount: 1,
      predictions: [
        StockoutRiskPredictionModel(
          fpsId: fpsId ?? 'FPS-KA-BLR-001',
          cycleId: cycleId,
          commodity: commodity,
          requestedDispatchKg: 1500.0,
          proposedAllocationKg: proposedAllocationKg ?? 1200.0,
          stockoutProbability: 0.125,
          riskTier: 'LOW',
          guidanceNote: 'Adequate stock coverage',
          daysOfStockCoverage: 45.0,
          deficitRatio: 0.0,
          modelName: 'LogisticRegression-Stockout-v1.0',
          features: {'inventory_kg': 500.0},
          governanceNotice: 'DEMO SYNTHETIC MODEL',
        ),
      ],
      demoNotice: 'DEMO SYNTHETIC MODEL',
    );
  }

  @override
  Future<ScarcityPlanSummaryModel> simulateFairShareScarcity({
    String cycleId = '2026-09',
    String depotId = 'DEPOT-01',
    String commodity = 'Rice',
    required double availableDepotStockKg,
    String allocationStrategy = 'FAIR_SHARE_RISK_WEIGHTED',
    bool persistCandidate = false,
    String actorName = 'District Supply Officer',
    String? notes,
  }) async {
    return ScarcityPlanSummaryModel(
      planId: 'PLAN-SCARCITY-2026-09-DEPOT-01-TEST',
      cycleId: cycleId,
      depotId: depotId,
      depotName: 'Bengaluru Central FCI Godown (Hebbal)',
      commodity: commodity,
      aggregateDemandKg: 5930.8,
      availableDepotStockKg: availableDepotStockKg,
      deficitKg: 0.0,
      deficitPercentage: 0.0,
      isScarcityCondition: false,
      scarcityCondition: 'NO_SCARCITY',
      statutoryFloorStatus: 'STATUTORY_FLOORS_SATISFIED',
      isStatutoryFloorSatisfied: true,
      allocationStrategy: allocationStrategy,
      totalStatutoryFloorsKg: 3694.4,
      totalReconciledAllocationKg: 5930.8,
      unallocatedDepotSlackKg: 0.0,
      averageCutPercentage: 0.0,
      allocatedFpsCount: 1,
      approvalStatus: 'PENDING_OFFICER_REVIEW',
      riskSummary: RiskSummaryModel.empty(),
      allocatedItems: [
        ScarcityAllocationItemModel(
          fpsId: 'FPS-KA-BLR-001',
          fpsName: 'Malleshwaram Seva Kendra (Demo)',
          baselineRecommendedKg: 5200.0,
          statutoryFloorKg: 350.0,
          reconciledAllocationKg: 5200.0,
          statutoryFloorSatisfied: true,
          floorDeficitKg: 0.0,
          cutKg: 0.0,
          cutPercentage: 0.0,
          predictedStockoutRisk: 0.125,
          riskTier: 'LOW',
          mitigationAction: 'Standard unconstrained supply dispatch.',
        ),
      ],
      demoNotice: 'DEMO PROTOTYPE',
    );
  }

  @override
  Future<ApprovePlanResponseModel> approveScarcityPlan({
    required String planId,
    required String officerName,
    String officerRole = 'DISTRICT_SUPPLY_OFFICER',
    String? approvalNotes,
  }) async {
    return ApprovePlanResponseModel(
      status: 'success',
      planId: planId,
      approvalStatus: 'OFFICER_APPROVED',
      approvedBy: '$officerName ($officerRole)',
      approvedAt: DateTime.now().toIso8601String(),
      depotId: 'DEPOT-01',
      commodity: 'Rice',
      totalReconciledAllocationKg: 5930.8,
      allocatedFpsCount: 1,
      message: 'Plan approved',
      demoNotice: 'DEMO PROTOTYPE',
    );
  }

  @override
  Future<ScarcityAuditTrailModel> fetchScarcityAuditTrail(String planId) async {
    return ScarcityAuditTrailModel(
      status: 'success',
      planId: planId,
      cycleId: '2026-09',
      depotId: 'DEPOT-01',
      commodity: 'Rice',
      aggregateDemandKg: 5930.8,
      availableStockKg: 25000.0,
      deficitKg: 0.0,
      allocationStrategy: 'FAIR_SHARE_RISK_WEIGHTED',
      approvalStatus: 'OFFICER_APPROVED',
      approvedBy: 'District Supply Officer (Demo Admin)',
      approvalNotes: 'Authorized',
      createdAt: DateTime.now().toIso8601String(),
      approvedAt: DateTime.now().toIso8601String(),
      allocatedFpsCount: 1,
      allocatedItems: [],
      demoNotice: 'DEMO PROTOTYPE',
    );
  }

  @override
  Future<AdminDashboardData> fetchAdminDashboard() async {
    return AdminDashboardData(
      district: 'Bengaluru Urban - Demo Nagar',
      activeCycle: '2026-09',
      totalFps: 20,
      activeIntentsCount: 480,
      totalDeclaredIntentKg: 16630.0,
      forecastGeneratedCount: 20,
      highRiskFpsCount: 4,
      mediumRiskFpsCount: 6,
      lowRiskFpsCount: 10,
      exceptionCasesCount: 159,
      totalInventoryKg: 155990.0,
      totalCapacityKg: 434000.0,
      averageCapacityUtilizationPct: 35.9,
      riskDistribution: {'HIGH': 4, 'MEDIUM': 6, 'LOW': 10},
      historicalCyclesTrend: [
        DistrictHistoricalTrend(cycleId: '2026-03', riceKg: 85000, wheatKg: 28000, totalKg: 113000),
        DistrictHistoricalTrend(cycleId: '2026-04', riceKg: 87000, wheatKg: 29000, totalKg: 116000),
      ],
      topIntentShiftFps: [
        {
          'fps_id': 'FPS-KA-BLR-013',
          'name': 'Peenya Industrial Area',
          'historical_kg': 6800.0,
          'intent_kg': 2400.0,
          'shift_kg': 350.0,
          'forecast_kg': 7100.0,
          'risk': 'HIGH'
        }
      ],
      fpsList: [
        AdminFpsRow(
          fpsId: 'FPS-KA-BLR-001',
          name: 'Malleshwaram Seva Kendra (Demo)',
          district: 'Bengaluru Urban - Demo District',
          latitude: 13.0031,
          longitude: 77.5643,
          capacityKg: 20000.0,
          registeredBeneficiaries: 100,
          historicalDemandKg: 6000.0,
          declaredIntentKg: 1800.0,
          intentShiftKg: -1200.0,
          intentShiftPct: -40.0,
          inventoryKg: 7000.0,
          inventoryUtilizationPct: 35.0,
          forecastKg: 5200.0,
          riskLevel: 'LOW',
          riskReason: 'Balanced Demand & Inventory',
          status: 'Planning',
        ),
      ],
      workflowStatus: 'PLANNING_OPEN',
    );
  }
}

void main() {
  testWidgets('DemoLoginScreen renders demo header, persona picker, and District Admin button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: DemoLoginScreen(apiService: MockApiService()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Login as District Admin (Demo Nagar)'), findsOneWidget);
    expect(find.text('Continue as Beneficiary'), findsOneWidget);
    expect(find.text('Swathi B. (Demo)'), findsWidgets);
  });

  testWidgets('AdminDashboardScreen renders KPI cards, visualizations, and FPS overview table',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(apiService: MockApiService()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('HISTORICAL BASELINE'), findsOneWidget);
    expect(find.text('INTENT DEMAND'), findsWidgets);
    expect(find.text('FORECAST DEMAND (D̂)'), findsOneWidget);
    expect(find.text('RECOMMENDED DISPATCH'), findsWidgets);
    expect(find.text('RISK & CONFIDENCE'), findsOneWidget);
    expect(find.text('DEPOT GRAIN BALANCE'), findsOneWidget);
    expect(find.text('AI Scarcity & Fair-Share'), findsOneWidget);
    expect(find.text('1. Forecast'), findsOneWidget);
    expect(find.text('FAIR PRICE SHOPS OVERVIEW MATRIX'), findsOneWidget);
  });

  testWidgets('ScarcityReconciliationDialog renders institutional tabs and simulation controls',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScarcityReconciliationDialog(
            cycleId: '2026-09',
            depotId: 'DEPOT-01',
            apiService: MockApiService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AI Stockout Risk Prediction & Scarcity Allocation Engine'), findsOneWidget);
    expect(find.text('1. Depot Supply vs Demand'), findsOneWidget);
    expect(find.text('2. AI Risk + Fair Share'), findsOneWidget);
    expect(find.text('3. Officer Approval + Audit'), findsOneWidget);
  });
}
