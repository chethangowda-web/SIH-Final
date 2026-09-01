import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/models/beneficiary_model.dart';
import 'package:pds_demandsync/models/admin_model.dart';
import 'package:pds_demandsync/models/scarcity_model.dart';
import 'package:pds_demandsync/screens/beneficiary/demo_login_screen.dart';
import 'package:pds_demandsync/screens/beneficiary/beneficiary_home_screen.dart';
import 'package:pds_demandsync/screens/beneficiary/intent_selection_screen.dart';
import 'package:pds_demandsync/screens/beneficiary/intent_confirmation_screen.dart';
import 'package:pds_demandsync/screens/admin/admin_dashboard_screen.dart';
import 'package:pds_demandsync/screens/admin/scarcity_reconciliation_dialog.dart';
import 'package:pds_demandsync/screens/admin/causal_trace_dialog.dart';
import 'package:pds_demandsync/screens/admin/citizen_request_queue_dialog.dart';
import 'package:pds_demandsync/services/api_service.dart';
import 'package:pds_demandsync/core/localization.dart';

class MockApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    final role = (username.startsWith('BEN-') ? 'BENEFICIARY' : 'ADMIN');
    final data = {
      'access_token': 'mock-jwt-token-for-$username',
      'token_type': 'bearer',
      'role': role,
      'beneficiary_id': username.startsWith('BEN-') ? username : null,
      'expires_in': 36000,
    };
    authSession.setSession(
      token: data['access_token'] as String,
      username: username,
      role: role,
      beneficiaryId: data['beneficiary_id'] as String?,
    );
    return data;
  }

  @override
  Future<List<FpsShop>> fetchFpsList() async {
    return [
      FpsShop(
        id: 1,
        fpsId: 'FPS-KA-BLR-001',
        name: 'Malleshwaram Seva Kendra',
        district: 'Bengaluru Urban',
        latitude: 12.9716,
        longitude: 77.5946,
        capacityKg: 20000.0,
        status: 'ACTIVE',
        currentInventoryTotalKg: 4000.0,
      ),
      FpsShop(
        id: 2,
        fpsId: 'FPS-KA-BLR-005',
        name: 'Bellandur Outer Ring Road',
        district: 'Bengaluru Urban',
        latitude: 12.9352,
        longitude: 77.6744,
        capacityKg: 25000.0,
        status: 'ACTIVE',
        currentInventoryTotalKg: 8000.0,
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchChoiceWindowStatus({String cycleId = '2026-09'}) async {
    return {'is_open': true, 'cycle_id': cycleId};
  }

  @override
  Future<List<Beneficiary>> fetchBeneficiaries({int limit = 100, int offset = 0, String? search}) async {
    return [
      Beneficiary(
        id: 1,
        pseudonymousBeneficiaryId: 'BEN-KA-0001',
        nameForDemo: 'Swathi Bhat',
        registeredFpsId: 'FPS-KA-BLR-001',
        registeredFpsName: 'Malleshwaram Seva Kendra',
        language: 'kn',
        status: 'ACTIVE',
      ),
    ];
  }

  @override
  Future<Beneficiary> fetchBeneficiaryDetail(String beneficiaryId) async {
    return Beneficiary(
      id: 1,
      pseudonymousBeneficiaryId: beneficiaryId,
      nameForDemo: 'Swathi Bhat',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      language: 'kn',
      status: 'ACTIVE',
    );
  }

  @override
  Future<BeneficiaryEntitlementSummary> fetchBeneficiaryEntitlementSummary(String beneficiaryId,
      {String cycleId = '2026-09'}) async {
    return BeneficiaryEntitlementSummary(
      beneficiaryId: beneficiaryId,
      name: 'Swathi Bhat',
      cardType: 'PHH',
      familyMembersCount: 5,
      cardLabel: 'Priority Household (PHH)',
      cycleId: cycleId,
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      statutoryEntitlementRiceKg: 20.0,
      statutoryEntitlementWheatKg: 5.0,
      consumedRiceKg: 0.0,
      consumedWheatKg: 0.0,
      remainingEligibleRiceKg: 20.0,
      remainingEligibleWheatKg: 5.0,
      totalEligibleBalanceKg: 25.0,
      transportPolicy: TransportFeeBreakdown(
        deliveryMode: 'FPS_COLLECTION',
        deliveryDistanceKm: 0.6,
        baseTransportFeeInr: 20.0,
        distanceSurchargeInr: 0.0,
        totalTransportFeeInr: 0.0,
        commodityCostInr: 0.0,
        totalPayableInr: 0.0,
        statutoryNotice: 'Statutory Notice',
      ),
    );
  }

  @override
  Future<List<IntentRecord>> fetchBeneficiaryIntents(String beneficiaryId, {String? cycleId}) async {
    return [];
  }

  @override
  Future<List<CitizenDeliveryRecord>> fetchBeneficiaryDeliveryRecords(String beneficiaryId,
      {String cycleId = '2026-09'}) async {
    return [];
  }

  @override
  Future<List<IntentRecord>> submitIntent({
    required String beneficiaryId,
    required String intendedFpsId,
    required String commodityOption,
    double? riceQuantityKg,
    double? wheatQuantityKg,
    String deliveryMode = 'FPS_COLLECTION',
    String? deliveryAddress,
    double deliveryDistanceKm = 0.0,
    String cycleId = '2026-09',
    double confidence = 0.95,
  }) async {
    return [
      IntentRecord(
        id: 1,
        beneficiaryId: beneficiaryId,
        cycleId: cycleId,
        intendedFpsId: intendedFpsId,
        intendedFpsName: 'Malleshwaram Seva Kendra',
        commodity: 'Rice',
        declaredQuantityKg: riceQuantityKg ?? 20.0,
        confidence: confidence,
        deliveryMode: deliveryMode,
        deliveryAddress: deliveryAddress,
        deliveryDistanceKm: deliveryDistanceKm,
        transportFeeInr: deliveryMode == 'HOME_DELIVERY' ? 20.0 : 0.0,
        deliveryStatus: 'SERVICE_REQUESTED',
        createdAt: '2026-08-28T10:00:00Z',
        status: 'SUBMITTED',
      ),
      IntentRecord(
        id: 2,
        beneficiaryId: beneficiaryId,
        cycleId: cycleId,
        intendedFpsId: intendedFpsId,
        intendedFpsName: 'Malleshwaram Seva Kendra',
        commodity: 'Wheat',
        declaredQuantityKg: wheatQuantityKg ?? 5.0,
        confidence: confidence,
        deliveryMode: deliveryMode,
        deliveryAddress: deliveryAddress,
        deliveryDistanceKm: deliveryDistanceKm,
        transportFeeInr: deliveryMode == 'HOME_DELIVERY' ? 20.0 : 0.0,
        deliveryStatus: 'SERVICE_REQUESTED',
        createdAt: '2026-08-28T10:00:00Z',
        status: 'SUBMITTED',
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
          fpsName: 'Malleshwaram Seva Kendra',
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
      district: 'Bengaluru Urban PDS Pilot',
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
          district: 'Bengaluru Urban PDS Pilot',
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

  @override
  Future<CausalTraceRun> fetchCausalTrace({String cycleId = '2026-09', String fpsId = 'FPS-KA-BLR-001'}) async {
    return _buildMockCausalTraceRun(fpsId);
  }

  @override
  Future<CausalTraceRun> runCausalTraceCalculation({String cycleId = '2026-09', String fpsId = 'FPS-KA-BLR-001'}) async {
    return _buildMockCausalTraceRun(fpsId);
  }

  @override
  Future<CausalTraceResponse> simulateIntentShiftCausalTrace({
    String cycleId = '2026-09',
    String fpsId = 'FPS-KA-BLR-001',
    double shiftDeltaKg = 150.0,
    String beneficiaryId = 'BEN-KA-0001',
  }) async {
    final run = _buildMockCausalTraceRun(fpsId);
    return CausalTraceResponse(
      status: 'success',
      currentRun: run,
      previousRun: run,
      causalDelta: CausalDeltaSummary(
        intentDeltaKg: 150.0,
        forecastDeltaKg: 97.5,
        dispatchDeltaKg: 97.5,
        routePayloadDeltaKg: 97.5,
        manifestVersionDelta: 'v1.0 -> v1.0',
        sealHashChanged: true,
        statutoryEntitlementDeltaKg: 0.0,
        propagationSummary: 'Citizen Intent Shift of +150.0 kg propagated downstream: Forecast changed +97.5 kg, Dispatch allocation updated +97.5 kg, Digital Manifest sealed with new SHA-256 hash.',
      ),
      message: 'Causal shift calculated successfully',
      demoNotice: 'DEMO PROTOTYPE',
    );
  }

  CausalTraceRun _buildMockCausalTraceRun(String fpsId) {
    return CausalTraceRun(
      runId: 'RUN-2026-09-$fpsId-A1B2C3D4',
      cycleId: '2026-09',
      fpsId: fpsId,
      fpsName: 'Malleshwaram Seva Kendra (Demo)',
      actorSource: 'DISTRICT_SUPPLY_OFFICER',
      timestamp: '2026-08-29 06:00:00 UTC+05:30',
      stage1Intent: CausalStageTraceModel(
        stageNumber: 1,
        stageName: 'INTENT_AGGREGATION',
        title: 'Citizen Forward Intent Signals',
        status: 'AGGREGATED',
        inputSummary: {'target_fps': fpsId, 'statutory_card_entitlement': '25.0 kg/card'},
        outputSummary: {'total_declared_intent_kg': 565.0, 'declaring_citizens_count': 14},
        governanceNotes: 'Citizen intent acts as forward planning signal only.',
        timestamp: '2026-08-29 06:00:00',
      ),
      stage2Forecast: CausalStageTraceModel(
        stageNumber: 2,
        stageName: 'OPERATIONAL_FORECAST',
        title: 'Composite AI Demand Forecast (D̂)',
        status: 'CALCULATED',
        inputSummary: {'historical_baseline_H_kg': 5999.4, 'aggregated_intent_I_kg': 565.0},
        outputSummary: {'operational_forecast_D_hat_kg': 2689.1},
        governanceNotes: 'Composite formula balances historical baseline with intent.',
        timestamp: '2026-08-29 06:00:00',
      ),
      stage3Constraints: CausalStageTraceModel(
        stageNumber: 3,
        stageName: 'CONSTRAINT_VALIDATION',
        title: '9 Statutory & Logistics Rules Audit',
        status: 'PASS',
        inputSummary: {'fps_capacity_kg': 20000.0},
        outputSummary: {'all_constraints_satisfied': true, 'active_alerts_count': 0},
        governanceNotes: '9 validation rules executed.',
        timestamp: '2026-08-29 06:00:00',
      ),
      stage4Dispatch: CausalStageTraceModel(
        stageNumber: 4,
        stageName: 'DISPATCH_DECISION',
        title: 'Authoritative Pre-Dispatch Recommendation (Q*)',
        status: 'AUTHORIZED',
        inputSummary: {'forecast_demand_kg': 2689.1},
        outputSummary: {'recommended_dispatch_Q_star_kg': 1200.0},
        governanceNotes: 'Official decision formula.',
        timestamp: '2026-08-29 06:00:00',
      ),
      stage5Route: CausalStageTraceModel(
        stageNumber: 5,
        stageName: 'ROUTE_OPTIMIZATION',
        title: 'TSP Multi-Stop Fleet Routing',
        status: 'OPTIMIZED',
        inputSummary: {'assigned_truck': 'DEMO-KA-04-E-1021'},
        outputSummary: {'total_corridor_payload_kg': 8400.0},
        governanceNotes: 'Traveling Salesperson TSP optimization.',
        timestamp: '2026-08-29 06:00:00',
      ),
      stage6Manifest: CausalStageTraceModel(
        stageNumber: 6,
        stageName: 'MANIFEST_GENERATION',
        title: 'Auditable Pre-Dispatch Manifest',
        status: 'LOCKED',
        inputSummary: {'manifest_id': 'MAN-2026-09-KA04E1021'},
        outputSummary: {'manifest_version': 'v1.0', 'status': 'LOCKED'},
        governanceNotes: 'Pre-dispatch manifest frozen.',
        timestamp: '2026-08-29 06:00:00',
      ),
      stage7Seal: CausalStageTraceModel(
        stageNumber: 7,
        stageName: 'DIGITAL_SEAL_AND_GATEPASS',
        title: 'Cryptographic SHA-256 Seal & Gatepass',
        status: 'SEALED',
        inputSummary: {'manifest_id': 'MAN-2026-09-KA04E1021'},
        outputSummary: {'digital_seal_sha256': '83BB4F2400E0A3A8431DD8127A62FCEB'},
        governanceNotes: 'Digital gatepass clearance granted.',
        timestamp: '2026-08-29 06:00:00',
      ),
      historicalDemandKg: 5999.4,
      aggregatedIntentKg: 565.0,
      operationalForecastKg: 2689.1,
      recommendedDispatchKg: 1200.0,
      assignedCorridor: 'North-West Heavy Corridor',
      assignedTruckId: 'DEMO-KA-04-E-1021',
      manifestId: 'MAN-2026-09-KA04E1021',
      manifestVersion: 'v1.0',
      digitalSealHash: '83BB4F2400E0A3A8431DD8127A62FCEB',
      statutoryEntitlementGuaranteeKg: 25.0,
      demoNotice: 'DEMO PROTOTYPE',
    );
  }

  @override
  Future<CitizenRequestQueueResponse> fetchCitizenRequestsQueue({
    String cycleId = '2026-09',
    String? status,
    String? fpsId,
    String? riskLevel,
  }) async {
    return CitizenRequestQueueResponse(
      cycleId: cycleId,
      totalCount: 1,
      pendingCount: 1,
      approvedCount: 0,
      partialCount: 0,
      redirectedCount: 0,
      deferredCount: 0,
      items: [
        CitizenRequestModel(
          id: 1,
          requestId: 'REQ-2026-09-0001',
          beneficiaryId: 'BEN-KA-0001',
          beneficiaryName: 'Swathi Bhat',
          cardType: 'PHH',
          familyMembersCount: 4,
          statutoryEntitlementRiceKg: 20.0,
          statutoryEntitlementWheatKg: 5.0,
          statutoryEntitlementCommodityKg: 20.0,
          cycleId: cycleId,
          registeredFpsId: 'FPS-KA-BLR-001',
          registeredFpsName: 'Malleshwaram Seva Kendra',
          intendedFpsId: 'FPS-KA-BLR-001',
          intendedFpsName: 'Malleshwaram Seva Kendra',
          commodity: 'Rice',
          requestedQuantityKg: 20.0,
          authorizedQuantityKg: 20.0,
          requestType: 'STANDARD_QUOTA',
          status: 'PENDING_OFFICER_REVIEW',
          aiRecommendation: 'APPROVE',
          aiRecommendedQtyKg: 20.0,
          aiRecommendedFpsId: 'FPS-KA-BLR-001',
          aiRiskLevel: 'LOW',
          aiConfidence: 0.95,
          aiFactors: ['Adequate FPS stock coverage', 'Historical collection adherence'],
          currentInventoryKg: 4000.0,
          statutoryFloorKg: 350.0,
          capacityHeadroomKg: 16000.0,
          replenishmentEta: '48h',
          createdAt: '2026-08-28T10:00:00Z',
        ),
      ],
    );
  }

  @override
  Future<List<DeliveryDisputeModel>> fetchDeliveryDisputes({
    String cycleId = '2026-09',
    String? status,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> authorizeCitizenRequest({
    required String requestId,
    required String officerName,
    required String officerRole,
    required String decision,
    double? allocatedQuantityKg,
    String? allocatedFpsId,
    required String officerJustification,
  }) async {
    return {
      'status': 'success',
      'request_id': requestId,
      'decision': decision,
      'message': 'Request authorized successfully',
    };
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

    expect(find.text('PDS DemandSync'), findsWidgets);
    expect(find.text('District Supply Officer — Bengaluru Urban'), findsOneWidget);
    expect(find.text('Continue as Beneficiary'), findsOneWidget);
    expect(find.text('Swathi Bhat'), findsWidgets);
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

    expect(find.text('HISTORICAL BASELINE'), findsWidgets);
    expect(find.text('INTENT DEMAND'), findsWidgets);
    expect(find.text('FORECAST DEMAND (D̂)'), findsWidgets);
    expect(find.text('RECOMMENDED DISPATCH'), findsWidgets);
    expect(find.text('RISK & CONFIDENCE'), findsWidgets);
    expect(find.text('Fair Price Shops Overview Matrix'), findsWidgets);
    expect(find.text('District Demand Trend'), findsOneWidget);
    expect(find.text('Run Pre-Dispatch Analysis'), findsOneWidget);

    // Open Operations dropdown to verify advanced operations
    await tester.tap(find.text('Operations ▾'));
    await tester.pumpAndSettle();
    expect(find.text('Scarcity & Fair-Share'), findsOneWidget);
    expect(find.text('Citizen Request Queue'), findsOneWidget);
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

  testWidgets('BeneficiaryHomeScreen renders hero entitlement, service choices, and policy notice',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: BeneficiaryHomeScreen(
          beneficiaryId: 'BEN-KA-0001',
          apiService: MockApiService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PDS DemandSync • Citizen Beneficiary Portal'), findsOneWidget);
    expect(find.text('YOUR RATION ENTITLEMENT'), findsOneWidget);
    expect(find.text('AVAILABLE REMAINING BALANCE'), findsOneWidget);
    expect(find.text('25.0'), findsOneWidget);
    expect(find.text('PLAN YOUR UPCOMING COLLECTION'), findsOneWidget);
    expect(find.text('Collect at Fair Price Shop'), findsOneWidget);
    expect(find.text('Assisted Home Delivery'), findsOneWidget);
    expect(find.text('Select Shop'), findsOneWidget);
    expect(find.text('Choose Delivery'), findsOneWidget);
    expect(
      find.text('Your ration entitlement is determined by government policy. You cannot increase or customize the quantity.'),
      findsOneWidget,
    );
  });

  testWidgets('IntentSelectionScreen renders 4-step stepper, service cards, and search filters',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final demoBeneficiary = Beneficiary(
      id: 1,
      pseudonymousBeneficiaryId: 'BEN-KA-0001',
      nameForDemo: 'Swathi Bhat',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      language: 'kn',
      status: 'ACTIVE',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IntentSelectionScreen(
          beneficiary: demoBeneficiary,
          apiService: MockApiService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Express Collection Preference'), findsOneWidget);
    expect(find.text('HOW WOULD YOU LIKE TO RECEIVE YOUR RATION?'), findsOneWidget);
    expect(find.text('Collect from Fair Price Shop'), findsOneWidget);
    expect(find.text('Assisted Home Delivery'), findsOneWidget);
    expect(find.text('CHOOSE YOUR INTENDED FAIR PRICE SHOP'), findsOneWidget);
    expect(find.text('Malleshwaram Seva Kendra'), findsOneWidget);
    expect(find.text('Home FPS'), findsOneWidget);
    expect(find.text('YOUR STATUTORY ENTITLEMENT SUMMARY'), findsOneWidget);
    expect(find.text('NON-EDITABLE'), findsOneWidget);
    expect(find.text('Continue to Review FPS Collection (₹0.00 Free)'), findsOneWidget);
  });

  testWidgets('IntentConfirmationScreen renders review step, governance notice, what happens next, and submits',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final demoBeneficiary = Beneficiary(
      id: 1,
      pseudonymousBeneficiaryId: 'BEN-KA-0001',
      nameForDemo: 'Swathi Bhat',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      language: 'kn',
      status: 'ACTIVE',
    );

    final demoFps = FpsShop(
      id: 1,
      fpsId: 'FPS-KA-BLR-001',
      name: 'Malleshwaram Seva Kendra',
      district: 'Bengaluru Urban',
      latitude: 12.9716,
      longitude: 77.5946,
      capacityKg: 20000.0,
      status: 'ACTIVE',
      currentInventoryTotalKg: 4000.0,
    );

    final mockApi = MockApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: IntentConfirmationScreen(
          beneficiary: demoBeneficiary,
          intendedFps: demoFps,
          commodityOption: 'Both',
          apiService: mockApi,
          deliveryMode: 'FPS_COLLECTION',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Review Step View
    expect(find.text('Review Your Collection Plan'), findsOneWidget);
    expect(find.text('REVIEW YOUR COLLECTION PLAN'), findsOneWidget);
    expect(find.text('SERVICE'), findsOneWidget);
    expect(find.text('LOCATION'), findsOneWidget);
    expect(find.text('CYCLE'), findsOneWidget);
    expect(find.text('ENTITLEMENT'), findsOneWidget);
    expect(find.text('REMAINING ENTITLEMENT'), findsOneWidget);
    expect(find.text('TOTAL PAYABLE / YOU PAY'), findsOneWidget);
    expect(find.text('₹0.00 (FREE)'), findsOneWidget);
    expect(find.text('IMPORTANT GOVERNANCE NOTICE'), findsOneWidget);
    expect(find.text('WHAT HAPPENS NEXT'), findsOneWidget);
    expect(find.text('Submit Collection Plan'), findsOneWidget);
    expect(find.text('Go Back & Edit Options'), findsOneWidget);

    // Scroll and Tap Submit Collection Plan
    await tester.ensureVisible(find.text('Submit Collection Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Collection Plan'));
    await tester.pumpAndSettle();

    // Verify Confirmed Step View
    expect(find.text('Collection Plan Submitted'), findsWidgets);
    expect(find.text('DIGITAL PREFERENCE RECEIPT'), findsOneWidget);
    expect(find.text('View Status in Citizen Portal'), findsOneWidget);
    expect(find.text('View All Ingested Signals'), findsOneWidget);
  });

  testWidgets('CausalTraceDialog renders 7 stages and delta calculation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CausalTraceDialog(
            apiService: mockApi,
            initialFpsId: 'FPS-KA-BLR-001',
            cycleId: '2026-09',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Header and Governance badges
    expect(find.text('End-to-End Causal Pipeline Trace'), findsOneWidget);
    expect(find.text('DETERMINISTIC PROPAGATION'), findsOneWidget);

    // Verify 7 Pipeline Stages
    expect(find.text('STAGE 1: Citizen Forward Intent Signals'), findsOneWidget);
    expect(find.text('STAGE 2: Composite AI Demand Forecast (D̂)'), findsOneWidget);
    expect(find.text('STAGE 3: 9 Statutory & Logistics Rules Audit'), findsOneWidget);
    expect(find.text('STAGE 4: Authoritative Pre-Dispatch Recommendation (Q*)'), findsOneWidget);
    expect(find.text('STAGE 5: TSP Multi-Stop Fleet Routing'), findsOneWidget);
    expect(find.text('STAGE 6: Auditable Pre-Dispatch Manifest'), findsOneWidget);
    expect(find.text('STAGE 7: Cryptographic SHA-256 Seal & Gatepass'), findsOneWidget);

    // Tap "Inject Intent Shift (+150 kg)"
    await tester.tap(find.text('Inject Intent Shift (+150 kg)'));
    await tester.pumpAndSettle();

    // Verify Causal Delta Banner appears
    expect(find.text('LIVE CAUSAL PROPAGATION DELTA DETECTED'), findsOneWidget);
    expect(find.text('STATUTORY ENTITLE: +0.0 kg (INVARIANT)'), findsOneWidget);
    expect(find.text('+150.0 kg'), findsOneWidget);
    expect(find.text('+97.5 kg'), findsWidgets);
  });

  testWidgets('CitizenRequestQueueDialog renders review queue and decision selector',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CitizenRequestQueueDialog(
            cycleId: '2026-09',
            apiService: MockApiService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Citizen Preference & Request Review Queue'), findsOneWidget);
    expect(find.text('CYCLE 2026-09'), findsOneWidget);

    // Verify Request Card
    expect(find.text('Swathi Bhat (BEN-KA-0001)'), findsOneWidget);
    expect(find.text('Statutory Quota'), findsOneWidget);
    expect(find.text('Requested Intent'), findsOneWidget);
    expect(find.text('Shop Stock / Statutory Floor'), findsOneWidget);

    // Verify Officer Action Controls
    expect(find.text('Authorized Government Action:'), findsOneWidget);
    expect(find.text('Full Quota'), findsOneWidget);
    expect(find.text('Partial (20kg)'), findsOneWidget);
    expect(find.text('Redirect FPS'), findsOneWidget);
    expect(find.text('Defer'), findsOneWidget);
    expect(find.text('Authorize'), findsOneWidget);
  });

  testWidgets('Beneficiary Portal switches reactively between English, Hindi, and Kannada',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Ensure English initially
    LanguageController.instance.setLanguage(AppLanguage.english);

    await tester.pumpWidget(
      MaterialApp(
        home: BeneficiaryHomeScreen(
          beneficiaryId: 'BEN-KA-0001',
          apiService: MockApiService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify English Labels
    expect(find.text('YOUR RATION ENTITLEMENT'), findsOneWidget);
    expect(find.text('Collect at Fair Price Shop'), findsOneWidget);
    expect(find.text('Assisted Home Delivery'), findsOneWidget);
    expect(find.text('Select Shop'), findsOneWidget);
    expect(find.text('Choose Delivery'), findsOneWidget);
    // Verify quantities & numbers are intact
    expect(find.text('25.0'), findsOneWidget);

    // 2. Switch to Hindi (हिंदी)
    LanguageController.instance.setLanguage(AppLanguage.hindi);
    await tester.pumpAndSettle();

    expect(find.text('आपकी राशन पात्रता'), findsOneWidget);
    expect(find.text('उचित मूल्य दुकान से प्राप्त करें'), findsOneWidget);
    expect(find.text('घर पर राशन डिलीवरी'), findsOneWidget);
    expect(find.text('दुकान चुनें'), findsOneWidget);
    expect(find.text('डिलीवरी चुनें'), findsOneWidget);
    // Quantities unchanged
    expect(find.text('25.0'), findsOneWidget);

    // 3. Switch to Kannada (ಕನ್ನಡ)
    LanguageController.instance.setLanguage(AppLanguage.kannada);
    await tester.pumpAndSettle();

    expect(find.text('ನಿಮ್ಮ ಪಡಿತರ ಪ್ರಮಾಣ'), findsOneWidget);
    expect(find.text('ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿಯಿಂದ ಪಡೆಯಿರಿ'), findsOneWidget);
    expect(find.text('ಮನೆಬಾಗಿಲಿಗೆ ಪಡಿತರ ವಿತರಣೆ'), findsOneWidget);
    expect(find.text('ಅಂಗಡಿ ಆಯ್ಕೆಮಾಡಿ'), findsOneWidget);
    expect(find.text('ವಿತರಣೆ ಆಯ್ಕೆಮಾಡಿ'), findsOneWidget);
    // Quantities unchanged
    expect(find.text('25.0'), findsOneWidget);

    // 4. Switch back to English
    LanguageController.instance.setLanguage(AppLanguage.english);
    await tester.pumpAndSettle();

    expect(find.text('YOUR RATION ENTITLEMENT'), findsOneWidget);
    expect(find.text('Collect at Fair Price Shop'), findsOneWidget);
  });
}
