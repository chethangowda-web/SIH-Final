import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/core/localization.dart';
import 'package:pds_demandsync/models/beneficiary_model.dart';
import 'package:pds_demandsync/screens/beneficiary/beneficiary_home_screen.dart';
import 'package:pds_demandsync/screens/beneficiary/biometric_verification_dialog.dart';
import 'package:pds_demandsync/screens/beneficiary/intent_selection_screen.dart';
import 'package:pds_demandsync/services/api_service.dart';

class MockHouseholdApiService extends ApiService {
  @override
  Future<Beneficiary> fetchBeneficiaryDetail(String beneficiaryId) async {
    return Beneficiary(
      id: 1,
      pseudonymousBeneficiaryId: beneficiaryId,
      nameForDemo: 'Swathi Bhat',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      language: 'en',
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
      familyMembersCount: 4,
      cardLabel: 'Priority Household (PHH)',
      cycleId: cycleId,
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      statutoryEntitlementRiceKg: 16.0,
      statutoryEntitlementWheatKg: 4.0,
      consumedRiceKg: 0.0,
      consumedWheatKg: 0.0,
      remainingEligibleRiceKg: 16.0,
      remainingEligibleWheatKg: 4.0,
      totalEligibleBalanceKg: 20.0,
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
  Future<List<FpsShop>> fetchFpsList() async {
    return [
      FpsShop(
        id: 1,
        fpsId: 'FPS-KA-BLR-001',
        name: 'Malleshwaram Seva Kendra',
        district: 'Bengaluru Urban',
        latitude: 12.9716,
        longitude: 77.5946,
        capacityKg: 30000.0,
        status: 'ACTIVE',
        currentInventoryTotalKg: 12000.0,
      ),
    ];
  }

  @override
  Future<List<IntentRecord>> fetchBeneficiaryIntents(String beneficiaryId, {String? cycleId}) async {
    return [
      IntentRecord(
        id: 101,
        beneficiaryId: beneficiaryId,
        cycleId: '2026-09',
        intendedFpsId: 'FPS-KA-BLR-001',
        intendedFpsName: 'Malleshwaram Seva Kendra',
        commodity: 'Rice',
        declaredQuantityKg: 16.0,
        confidence: 0.95,
        deliveryMode: 'FPS_COLLECTION',
        deliveryStatus: 'ARRIVED_AT_DESTINATION',
        createdAt: '2026-08-28T10:00:00Z',
        status: 'SUBMITTED',
      ),
      IntentRecord(
        id: 102,
        beneficiaryId: beneficiaryId,
        cycleId: '2026-09',
        intendedFpsId: 'FPS-KA-BLR-001',
        intendedFpsName: 'Malleshwaram Seva Kendra',
        commodity: 'Wheat',
        declaredQuantityKg: 4.0,
        confidence: 0.95,
        deliveryMode: 'FPS_COLLECTION',
        deliveryStatus: 'ARRIVED_AT_DESTINATION',
        createdAt: '2026-08-28T10:00:00Z',
        status: 'SUBMITTED',
      ),
    ];
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
        id: 101,
        beneficiaryId: beneficiaryId,
        cycleId: cycleId,
        intendedFpsId: intendedFpsId,
        commodity: 'Rice',
        declaredQuantityKg: riceQuantityKg ?? 16.0,
        confidence: confidence,
        deliveryMode: deliveryMode,
        deliveryStatus: 'SERVICE_REQUESTED',
        createdAt: '2026-08-28T10:00:00Z',
        status: 'SUBMITTED',
      ),
      IntentRecord(
        id: 102,
        beneficiaryId: beneficiaryId,
        cycleId: cycleId,
        intendedFpsId: intendedFpsId,
        commodity: 'Wheat',
        declaredQuantityKg: wheatQuantityKg ?? 4.0,
        confidence: confidence,
        deliveryMode: deliveryMode,
        deliveryStatus: 'SERVICE_REQUESTED',
        createdAt: '2026-08-28T10:00:00Z',
        status: 'SUBMITTED',
      ),
    ];
  }
}

void main() {
  setUp(() {
    LanguageController.instance.setLanguage(AppLanguage.english);
  });

  group('Household-Based Entitlement & Biometric Verification Tests', () {
    testWidgets('BeneficiaryHomeScreen displays household selector, formula, and updates calculations',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockApi = MockHouseholdApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: BeneficiaryHomeScreen(
            beneficiaryId: 'BEN-KA-0001',
            apiService: mockApi,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Household Members Selector Section
      expect(find.byKey(const ValueKey('card_household_members_selector')), findsOneWidget);
      expect(find.text('ELIGIBLE HOUSEHOLD MEMBERS'), findsOneWidget);
      expect(find.text('5.0 kg / ELIGIBLE PERSON'), findsOneWidget);
      expect(find.text('4 Members × 5.0 kg = 20.0 kg Maximum Household Quota'), findsOneWidget);

      // Verify Hero card calculations
      expect(find.text('20.0'), findsOneWidget);

      // 2. Increment members to 5 (5 x 5 = 25.0 kg)
      await tester.tap(find.byKey(const ValueKey('btn_increment_members')));
      await tester.pumpAndSettle();

      expect(find.text('5 Members × 5.0 kg = 25.0 kg Maximum Household Quota'), findsOneWidget);
      expect(find.text('25.0'), findsOneWidget);

      // 3. Increment members to 6 (6 x 5 = 30.0 kg)
      await tester.tap(find.byKey(const ValueKey('btn_increment_members')));
      await tester.pumpAndSettle();

      expect(find.text('6 Members × 5.0 kg = 30.0 kg Maximum Household Quota'), findsOneWidget);
      expect(find.text('30.0'), findsOneWidget);

      // 4. Decrement members back to 3 (3 x 5 = 15.0 kg)
      await tester.tap(find.byKey(const ValueKey('btn_decrement_members')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('btn_decrement_members')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('btn_decrement_members')));
      await tester.pumpAndSettle();

      expect(find.text('3 Members × 5.0 kg = 15.0 kg Maximum Household Quota'), findsOneWidget);
      expect(find.text('15.0'), findsOneWidget);
    });

    testWidgets('BiometricVerificationDialog performs 3-point check, tests match vs failure, and distributes foodgrain',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool verifiedSuccess = false;
      double distributedAmount = 0.0;

      final mockBen = Beneficiary(
        id: 1,
        pseudonymousBeneficiaryId: 'BEN-KA-0001',
        nameForDemo: 'Swathi Bhat',
        registeredFpsId: 'FPS-KA-BLR-001',
        registeredFpsName: 'Malleshwaram Seva Kendra',
        language: 'en',
        status: 'ACTIVE',
      );
      final mockEnt = BeneficiaryEntitlementSummary(
        beneficiaryId: 'BEN-KA-0001',
        name: 'Swathi Bhat',
        cardType: 'PHH',
        familyMembersCount: 4,
        cardLabel: 'Priority Household (PHH)',
        cycleId: '2026-09',
        registeredFpsId: 'FPS-KA-BLR-001',
        registeredFpsName: 'Malleshwaram Seva Kendra',
        statutoryEntitlementRiceKg: 16.0,
        statutoryEntitlementWheatKg: 4.0,
        consumedRiceKg: 0.0,
        consumedWheatKg: 0.0,
        remainingEligibleRiceKg: 16.0,
        remainingEligibleWheatKg: 4.0,
        totalEligibleBalanceKg: 20.0,
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('btn_open_dialog'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => BiometricVerificationDialog(
                      beneficiary: mockBen,
                      entitlement: mockEnt,
                      deliveryMode: 'FPS_COLLECTION',
                      fpsName: 'Malleshwaram Seva Kendra',
                      riceQtyKg: 16.0,
                      wheatQtyKg: 4.0,
                      eligibleMembersCount: 4,
                      onDistributionComplete: (distributedKg, remainingKg) {
                        verifiedSuccess = true;
                        distributedAmount = distributedKg;
                      },
                    ),
                  );
                },
                child: const Text('Open Biometric Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Dialog
      await tester.tap(find.byKey(const ValueKey('btn_open_dialog')));
      await tester.pumpAndSettle();

      // Verify Dialog Elements
      expect(find.text('FPS COUNTER BIOMETRIC VERIFICATION'), findsOneWidget);
      expect(find.text('1. Citizen Identity & Aadhaar Demographic Match'), findsOneWidget);
      expect(find.text('2. Ration Card Active & Non-Suspended'), findsOneWidget);
      expect(find.text('3. Available Household Quota Ceiling'), findsOneWidget);

      // 1. Test Failure / Mismatch Simulation
      await tester.tap(find.byKey(const ValueKey('btn_simulate_failure')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('✕ Verification Failed — Distribution Locked'), findsOneWidget);

      // 2. Test Success / Verified Match Simulation
      await tester.tap(find.byKey(const ValueKey('btn_simulate_success')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('✓ Beneficiary Verified & Entitlement Available'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_distribute_foodgrain')), findsOneWidget);

      // 3. Confirm Distribution Handover
      await tester.tap(find.byKey(const ValueKey('btn_distribute_foodgrain')));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      expect(verifiedSuccess, isTrue);
      expect(distributedAmount, equals(20.0));
    });

    testWidgets('IntentSelectionScreen locks commodity quantities as fixed read-only entitlement',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockApi = MockHouseholdApiService();
      final mockBen = Beneficiary(
        id: 1,
        pseudonymousBeneficiaryId: 'BEN-KA-0001',
        nameForDemo: 'Swathi Bhat',
        registeredFpsId: 'FPS-KA-BLR-001',
        registeredFpsName: 'Malleshwaram Seva Kendra',
        language: 'en',
        status: 'ACTIVE',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IntentSelectionScreen(
            beneficiary: mockBen,
            apiService: mockApi,
            initialEligibleMembersCount: 3, // 3 x 5 = 15.0 kg Max (12 kg Rice + 3 kg Wheat)
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Household Allocation Section for 3 members (15.0 kg max)
      expect(find.byKey(const ValueKey('section_household_allocation')), findsOneWidget);
      expect(find.text('3 Members × 5.0 kg = 15.0 kg Maximum Household Quota'), findsOneWidget);
      expect(find.text('15.0 / 15.0 kg'), findsOneWidget);

      // Verify Rice and Wheat are fixed read-only values
      expect(find.text('12.0 kg'), findsOneWidget);
      expect(find.text('3.0 kg'), findsOneWidget);

      // Verify NO stepper / increment / decrement buttons exist anywhere for commodities
      expect(find.byKey(const ValueKey('btn_increment_rice')), findsNothing);
      expect(find.byKey(const ValueKey('btn_decrement_rice')), findsNothing);
      expect(find.byKey(const ValueKey('btn_increment_wheat')), findsNothing);
      expect(find.byKey(const ValueKey('btn_decrement_wheat')), findsNothing);

      // 2. Increment members to 4 (4 x 5 = 20.0 kg Max -> 16 kg Rice + 4 kg Wheat)
      await tester.ensureVisible(find.byKey(const ValueKey('btn_intent_increment_members')));
      await tester.tap(find.byKey(const ValueKey('btn_intent_increment_members')));
      await tester.pumpAndSettle();

      expect(find.text('4 Members × 5.0 kg = 20.0 kg Maximum Household Quota'), findsOneWidget);
      expect(find.text('20.0 / 20.0 kg'), findsOneWidget);
      expect(find.text('16.0 kg'), findsOneWidget);
      expect(find.text('4.0 kg'), findsOneWidget);

      // Submit/continue button is available
      final submitButton = find.byKey(const ValueKey('btn_continue_to_review'));
      expect(submitButton, findsOneWidget);
    });

    testWidgets('BeneficiaryHomeScreen displays Expected Delivery Timer and counts down reactively',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockApi = MockHouseholdApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: BeneficiaryHomeScreen(
            beneficiaryId: 'BEN-KA-0001',
            apiService: mockApi,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Expected Delivery Timer Card should be visible on active delivery
      expect(find.byKey(const ValueKey('card_expected_delivery_timer')), findsOneWidget);
      expect(find.byKey(const ValueKey('text_eta_countdown')), findsOneWidget);
      expect(find.text('EXPECTED DELIVERY'), findsOneWidget);

      // Get initial countdown text
      final initialTextFinder = find.byKey(const ValueKey('text_eta_countdown'));
      final initialTextWidget = tester.widget<Text>(initialTextFinder);
      final initialCountdown = initialTextWidget.data;
      expect(initialCountdown, isNotNull);

      // 2. Advance clock by 2 seconds to verify reactive countdown
      await tester.pump(const Duration(seconds: 2));

      final updatedTextWidget = tester.widget<Text>(initialTextFinder);
      final updatedCountdown = updatedTextWidget.data;

      // Countdown should not be null or negative
      expect(updatedCountdown, isNotNull);
      expect(updatedCountdown!.contains('-'), isFalse);
    });

    testWidgets('Multilingual switching translates household, biometric, and ETA strings accurately',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockApi = MockHouseholdApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: BeneficiaryHomeScreen(
            beneficiaryId: 'BEN-KA-0001',
            apiService: mockApi,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. English
      expect(find.text('ELIGIBLE HOUSEHOLD MEMBERS'), findsOneWidget);
      expect(find.text('5.0 kg / ELIGIBLE PERSON'), findsOneWidget);
      expect(find.text('EXPECTED DELIVERY'), findsOneWidget);

      // 2. Switch to Hindi (हिंदी)
      LanguageController.instance.setLanguage(AppLanguage.hindi);
      await tester.pumpAndSettle();

      expect(find.text('पात्र परिवार के सदस्य'), findsOneWidget);
      expect(find.text('5.0 किग्रा / पात्र व्यक्ति'), findsOneWidget);
      expect(find.text('अपेक्षित डिलीवरी समय'), findsOneWidget);

      // 3. Switch to Kannada (ಕನ್ನಡ)
      LanguageController.instance.setLanguage(AppLanguage.kannada);
      await tester.pumpAndSettle();

      expect(find.text('ಅರ್ಹ ಕುಟುಂಬ ಸದಸ್ಯರು'), findsOneWidget);
      expect(find.text('5.0 ಕೆ.ಜಿ. / ಅರ್ಹ ವ್ಯಕ್ತಿಗೆ'), findsOneWidget);
      expect(find.text('ನಿರೀಕ್ಷಿತ ವಿತರಣಾ ಸಮಯ'), findsOneWidget);
    });
  });
}
