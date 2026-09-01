import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/core/localization.dart';
import 'package:pds_demandsync/models/admin_model.dart';
import 'package:pds_demandsync/models/beneficiary_model.dart';
import 'package:pds_demandsync/screens/admin/predispatch_analysis_dialog.dart';
import 'package:pds_demandsync/screens/beneficiary/beneficiary_home_screen.dart';
import 'package:pds_demandsync/services/api_service.dart';
import 'package:pds_demandsync/widgets/delivery_timeline.dart';
import 'package:pds_demandsync/widgets/status_badge.dart';

class MockDelayedApiService extends ApiService {
  @override
  Future<Beneficiary> fetchBeneficiaryDetail(String beneficiaryId) async {
    return Beneficiary(
      id: 1,
      pseudonymousBeneficiaryId: 'BEN-KA-BLR-001',
      nameForDemo: 'Swathi Rao',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Indiranagar Fair Price Depot #42',
      language: 'kn',
      status: 'ACTIVE',
    );
  }

  @override
  Future<BeneficiaryEntitlementSummary> fetchBeneficiaryEntitlementSummary(
    String beneficiaryId, {
    String cycleId = '2026-09',
  }) async {
    return BeneficiaryEntitlementSummary(
      beneficiaryId: 'BEN-KA-BLR-001',
      name: 'Swathi Rao',
      cardType: 'PHH',
      familyMembersCount: 4,
      cardLabel: 'Priority Household (PHH)',
      cycleId: '2026-09',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Indiranagar Fair Price Depot #42',
      statutoryEntitlementRiceKg: 20.0,
      statutoryEntitlementWheatKg: 5.0,
      consumedRiceKg: 0.0,
      consumedWheatKg: 0.0,
      remainingEligibleRiceKg: 20.0,
      remainingEligibleWheatKg: 5.0,
      totalEligibleBalanceKg: 25.0,
      transportPolicy: TransportFeeBreakdown(
        deliveryMode: 'FPS_COLLECTION',
        deliveryDistanceKm: 0.0,
        baseTransportFeeInr: 0.0,
        distanceSurchargeInr: 0.0,
        totalTransportFeeInr: 0.0,
        commodityCostInr: 0.0,
        totalPayableInr: 0.0,
        statutoryNotice: 'Self-collection at Fair Price Shop is 100% free of cost.',
      ),
    );
  }

  @override
  Future<List<IntentRecord>> fetchBeneficiaryIntents(
    String beneficiaryId, {
    String? cycleId,
  }) async {
    return [];
  }

  @override
  Future<List<CitizenDeliveryRecord>> fetchBeneficiaryDeliveryRecords(
    String beneficiaryId, {
    String? cycleId,
  }) async {
    return [
      CitizenDeliveryRecord(
        id: 101,
        requestId: 'REQ-202609-001-R',
        beneficiaryId: 'BEN-KA-BLR-001',
        cycleId: '2026-09',
        commodity: 'Rice',
        requestedQuantityKg: 20.0,
        authorizedQuantityKg: 20.0,
        deliveryMode: 'HOME_DELIVERY',
        deliveryAddress: '12th Main Road, Indiranagar, Bengaluru',
        deliveryDistanceKm: 3.5,
        transportFeeInr: 87.50,
        deliveryStatus: 'DELAYED',
        receivedRiceKg: 0.0,
        receivedWheatKg: 0.0,
        status: 'OFFICER_APPROVED',
        registeredFpsName: 'Indiranagar Fair Price Depot #42',
        intendedFpsName: 'Indiranagar Fair Price Depot #42',
        delayReason: 'Government stock currently unavailable for this dispatch.',
        expectedDeliveryWindow: 'Within 1–2 Days',
        createdAt: '2026-09-01T08:00:00Z',
      ),
      CitizenDeliveryRecord(
        id: 102,
        requestId: 'REQ-202609-001-W',
        beneficiaryId: 'BEN-KA-BLR-001',
        cycleId: '2026-09',
        commodity: 'Wheat',
        requestedQuantityKg: 5.0,
        authorizedQuantityKg: 5.0,
        deliveryMode: 'HOME_DELIVERY',
        deliveryAddress: '12th Main Road, Indiranagar, Bengaluru',
        deliveryDistanceKm: 3.5,
        transportFeeInr: 87.50,
        deliveryStatus: 'DELAYED',
        receivedRiceKg: 0.0,
        receivedWheatKg: 0.0,
        status: 'OFFICER_APPROVED',
        registeredFpsName: 'Indiranagar Fair Price Depot #42',
        intendedFpsName: 'Indiranagar Fair Price Depot #42',
        delayReason: 'Government stock currently unavailable for this dispatch.',
        expectedDeliveryWindow: 'Within 1–2 Days',
        createdAt: '2026-09-01T08:00:00Z',
      ),
    ];
  }

  @override
  Future<PreDispatchAnalysisResult> runPreDispatchAnalysis(
      {String? fpsId, String cycleId = '2026-09', bool simulateStockShortage = false}) async {
    return PreDispatchAnalysisResult(
      status: 'success',
      analysisMode: 'DISTRICT_WIDE',
      pipelineStages: [
        PipelineStageItem(stage: '1. FORECAST', status: 'COMPLETED', value: '62.7 MT Demand', elapsedSeconds: 3),
        PipelineStageItem(stage: '2. VALIDATE', status: 'COMPLETED', value: '9 Invariants Verified', elapsedSeconds: 2),
        PipelineStageItem(stage: '3. OPTIMIZE', status: 'COMPLETED', value: '4 Corridors', elapsedSeconds: 3),
        PipelineStageItem(stage: '4. MANIFEST', status: 'COMPLETED', value: 'SHA-256 Gatepass', elapsedSeconds: 2),
      ],
      message: 'Pre-dispatch analysis executed.',
      stockConstraintDetected: simulateStockShortage,
    );
  }

  @override
  Future<Map<String, dynamic>> delayDispatch({
    String? fpsId,
    String? requestId,
    String? beneficiaryId,
    String delayDays = '1–2 days',
    String reason = 'Government stock currently unavailable for this dispatch.',
    String cycleId = '2026-09',
  }) async {
    return {
      'status': 'DELAYED',
      'message': 'Dispatch delayed by 1–2 days due to government stock replenishment.',
    };
  }

  @override
  Future<Map<String, dynamic>> resumeDispatch({
    String? fpsId,
    String? requestId,
    String? beneficiaryId,
    String cycleId = '2026-09',
  }) async {
    return {
      'status': 'OUT_FOR_DELIVERY',
      'message': 'Stock replenished! Dispatch resumed and moved to Out for Delivery.',
    };
  }

  @override
  Future<Map<String, dynamic>> sendDelayAlert({
    required String beneficiaryId,
    String? beneficiaryName,
    String? fpsId,
    String? requestId,
    String delayDays = '1–2 days',
    String? customMessage,
    String cycleId = '2026-09',
  }) async {
    return {
      'status': 'SENT',
      'channel': 'SMS',
      'recipient': beneficiaryId,
      'message': 'Official stock shortage delay alert dispatched to beneficiary via SMS.',
    };
  }

  @override
  Future<List<NotificationLogRecord>> fetchNotificationLogs({
    String cycleId = '2026-09',
    String? recipientType,
  }) async {
    return [
      NotificationLogRecord(
        id: 1,
        cycleId: '2026-09',
        recipientType: 'BENEFICIARY',
        recipientId: 'BEN-KA-0001',
        recipientName: 'Swathi Bhat',
        recipientPhone: '+91 98450 12345',
        fpsId: 'FPS-KA-BLR-001',
        fpsName: 'Indiranagar FPS #42',
        channel: 'SMS',
        messageTitle: 'Stock Shortage Temporary Delay Notice',
        messageBody: 'Your ration delivery has been temporarily delayed (1-2 days) due to government stock availability.',
        status: 'DELIVERED',
        sentAt: '2026-09-01 10:30:00',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pre-Dispatch Live Timers & Shortage Delay Tests', () {
    testWidgets('StatusBadge renders DELAYED amber label correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'DELAYED'),
          ),
        ),
      );

      expect(find.text('DELAYED — STOCK REPLENISHMENT PENDING'), findsOneWidget);
    });

    testWidgets('DeliveryTimeline handles DELAYED status with temporary delay indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryTimeline(currentStatus: 'DELAYED'),
          ),
        ),
      );

      expect(find.text('TEMPORARY DELAY (1–2 DAYS)'), findsOneWidget);
      expect(find.text('Allocated'), findsOneWidget);
    });

    testWidgets('PreDispatchAnalysisDialog displays 4-stage pipeline with live elapsed timers', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockApi = MockDelayedApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreDispatchAnalysisDialog(
              apiService: mockApi,
            ),
          ),
        ),
      );

      // Initial render shows pipeline modal title
      expect(find.text('Pre-Dispatch Decision Intelligence Analysis'), findsOneWidget);
      expect(find.text('1. FORECAST'), findsOneWidget);
      expect(find.text('2. VALIDATE'), findsOneWidget);
      expect(find.text('3. OPTIMIZE'), findsOneWidget);
      expect(find.text('4. MANIFEST'), findsOneWidget);

      // Advance simulated timer through stages
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('Lock Manifest & Proceed to Fleet Dispatch'), findsOneWidget);
    });

    testWidgets('PreDispatchAnalysisDialog Scenario B detects stock constraint and shows temporary delay action', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockApi = MockDelayedApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreDispatchAnalysisDialog(
              apiService: mockApi,
            ),
          ),
        ),
      );

      // Switch to Scenario B: Stock Shortage
      final scenarioBChip = find.text('Scenario B: Government Stock Shortage (1–2 Day Temporary Delay)');
      expect(scenarioBChip, findsOneWidget);
      await tester.tap(scenarioBChip);
      await tester.pump();

      // Advance timer for Scenario B (stage 0 takes 3s, stage 1 takes 2s)
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Check operational warning and delay action
      expect(find.textContaining('Stock Constraint Detected'), findsWidgets);
      expect(find.text('Delay Dispatch (1–2 Days) & Notify Beneficiaries'), findsOneWidget);
      expect(find.textContaining('Stock shortage represents a temporary delay, NOT a cancellation'), findsOneWidget);
    });

    testWidgets('BeneficiaryHomeScreen displays Delivery Delayed alert card and retains full order breakdown', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockApi = MockDelayedApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: BeneficiaryHomeScreen(
            beneficiaryId: 'BEN-KA-BLR-001',
            apiService: mockApi,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check prominent Delivery Delayed alert card is rendered
      expect(find.byKey(const ValueKey('card_stock_delay_alert')), findsOneWidget);
      expect(find.text('⏳ Delivery Delayed'), findsOneWidget);
      expect(find.textContaining('Your ration delivery is temporarily delayed due to government stock availability'), findsOneWidget);
      expect(find.textContaining('Within 1–2 Days'), findsWidgets);
      expect(find.textContaining('You do not need to submit your request again'), findsOneWidget);

      // Check order details remain 100% visible and intact
      expect(find.text('Order #REQ-202609-001'), findsOneWidget);
      expect(find.textContaining('20.0 kg'), findsWidgets);
      expect(find.textContaining('5.0 kg'), findsWidgets);
      expect(find.text('DELAYED — STOCK REPLENISHMENT PENDING'), findsOneWidget);
    });

    test('MockDelayedApiService resumeDispatch and sendDelayAlert contracts execute successfully', () async {
      final mockApi = MockDelayedApiService();
      
      // Verify delay alert API
      final alertRes = await mockApi.sendDelayAlert(
        beneficiaryId: 'BEN-KA-0001',
        beneficiaryName: 'Swathi Bhat',
        delayDays: '1–2 days',
      );
      expect(alertRes['status'], 'SENT');
      expect(alertRes['channel'], 'SMS');

      // Verify resume dispatch API
      final resumeRes = await mockApi.resumeDispatch(cycleId: '2026-09');
      expect(resumeRes['status'], 'OUT_FOR_DELIVERY');
      expect(resumeRes['message'], contains('Dispatch resumed'));
    });
  });
}
