import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/core/localization.dart';
import 'package:pds_demandsync/models/beneficiary_model.dart';
import 'package:pds_demandsync/screens/beneficiary/intent_selection_screen.dart';
import 'package:pds_demandsync/services/api_service.dart';
import 'package:pds_demandsync/services/voice_assistant_service.dart';

class MockEntitlementApiService extends ApiService {
  final int membersCount;
  final double riceKg;
  final double wheatKg;
  final String cardType;

  MockEntitlementApiService({
    this.membersCount = 4,
    this.riceKg = 15.0,
    this.wheatKg = 5.0,
    this.cardType = 'PHH',
  });

  @override
  Future<List<FpsShop>> fetchFpsList() async {
    return [
      FpsShop(
        id: 1,
        fpsId: 'FPS-KA-BLR-001',
        name: 'Malleshwaram Seva Kendra',
        district: 'Bengaluru Urban',
        latitude: 13.0031,
        longitude: 77.5643,
        capacityKg: 30000.0,
        status: 'ACTIVE',
        currentInventoryTotalKg: 12500.0,
      ),
    ];
  }

  @override
  Future<BeneficiaryEntitlementSummary> fetchBeneficiaryEntitlementSummary(
    String beneficiaryId, {
    String cycleId = '2026-09',
  }) async {
    return BeneficiaryEntitlementSummary(
      beneficiaryId: beneficiaryId,
      name: 'Swathi Bhat',
      cardType: cardType,
      familyMembersCount: membersCount,
      cardLabel: 'Priority Household ($cardType)',
      cycleId: cycleId,
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      statutoryEntitlementRiceKg: riceKg,
      statutoryEntitlementWheatKg: wheatKg,
      consumedRiceKg: 0.0,
      consumedWheatKg: 0.0,
      remainingEligibleRiceKg: riceKg,
      remainingEligibleWheatKg: wheatKg,
      totalEligibleBalanceKg: riceKg + wheatKg,
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
      rationReceivedForCycle: false,
    );
  }

  @override
  Future<List<CitizenDeliveryRecord>> fetchBeneficiaryDeliveryRecords(
    String beneficiaryId, {
    String cycleId = '2026-09',
  }) async {
    return [];
  }
}

void main() {
  setUp(() {
    LanguageController.instance.setLanguage(AppLanguage.english);
    VoiceAssistantService.instance.stopVoiceAssistantMode();
  });

  tearDown(() {
    LanguageController.instance.setLanguage(AppLanguage.english);
    VoiceAssistantService.instance.stopVoiceAssistantMode();
  });

  testWidgets('1. Grain selection UI is completely removed and replaced by Entitlement Card', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final demoBeneficiary = Beneficiary(
      id: 1,
      pseudonymousBeneficiaryId: 'BEN-KA-0001',
      nameForDemo: 'Swathi Bhat',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      language: 'en',
      status: 'ACTIVE',
    );

    final mockApi = MockEntitlementApiService(
      membersCount: 4,
      riceKg: 15.0,
      wheatKg: 5.0,
      cardType: 'PHH',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IntentSelectionScreen(
          beneficiary: demoBeneficiary,
          apiService: mockApi,
          initialEligibleMembersCount: 4,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Completely REMOVED grain choice elements
    expect(find.text('What do you need next time?'), findsNothing);
    expect(find.text('Rice Only'), findsNothing);
    expect(find.text('Wheat Only'), findsNothing);
    expect(find.text('Both (Rice + Wheat)'), findsNothing);
    expect(find.text('Recommended'), findsNothing);
    expect(find.byKey(const ValueKey('section_visual_grain_choices')), findsNothing);

    // 2. CLEAR ENTITLEMENT CARD is present
    expect(find.byKey(const ValueKey('section_entitlement_card')), findsOneWidget);
    expect(find.text("YOUR FAMILY'S RATION ENTITLEMENT"), findsOneWidget);

    // 3. Displays actual dataset values: 4 members, 15 kg rice, 5 kg wheat, 20 kg total
    expect(find.text('Family Members: '), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Rice'), findsWidgets);
    expect(find.text('15 kg'), findsWidgets);
    expect(find.text('Wheat'), findsWidgets);
    expect(find.text('5 kg'), findsWidgets);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('20 kg'), findsWidgets);
    expect(find.text('This is your eligible quantity for this distribution cycle.'), findsOneWidget);

    // 4. FPS selection and map flow are preserved
    expect(find.text('CHOOSE YOUR INTENDED FAIR PRICE SHOP'), findsOneWidget);
    expect(find.text('Malleshwaram Seva Kendra'), findsOneWidget);
    expect(find.byKey(const ValueKey('btn_continue_to_review')), findsOneWidget);
  });

  testWidgets('2. Displays correct entitlement for secondary beneficiary RC-KA-000001 (2 members, 10kg)', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final secondBeneficiary = Beneficiary(
      id: 2,
      pseudonymousBeneficiaryId: 'RC-KA-000001',
      nameForDemo: 'Deepa Reddy',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      language: 'en',
      status: 'ACTIVE',
    );

    final mockApi = MockEntitlementApiService(
      membersCount: 2,
      riceKg: 0.0,
      wheatKg: 10.0,
      cardType: 'PHH',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IntentSelectionScreen(
          beneficiary: secondBeneficiary,
          apiService: mockApi,
          initialEligibleMembersCount: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 2 members, 0 kg rice, 10 kg wheat, 10 kg total inside entitlement card
    final cardFinder = find.byKey(const ValueKey('section_entitlement_card'));
    expect(cardFinder, findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('0 kg')), findsOneWidget);
    expect(find.descendant(of: cardFinder, matching: find.text('10 kg')), findsWidgets);
  });

  testWidgets('3. Multilingual support: Hindi and Kannada translations render correctly', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final demoBeneficiary = Beneficiary(
      id: 1,
      pseudonymousBeneficiaryId: 'BEN-KA-0001',
      nameForDemo: 'Swathi Bhat',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      language: 'hi',
      status: 'ACTIVE',
    );

    final mockApi = MockEntitlementApiService(
      membersCount: 4,
      riceKg: 15.0,
      wheatKg: 5.0,
    );

    // Switch to Hindi
    LanguageController.instance.setLanguage(AppLanguage.hindi);

    await tester.pumpWidget(
      MaterialApp(
        home: IntentSelectionScreen(
          beneficiary: demoBeneficiary,
          apiService: mockApi,
          initialEligibleMembersCount: 4,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Hindi labels
    expect(find.text('आपके परिवार का राशन हक'), findsWidgets);
    expect(find.text('परिवार के सदस्य: '), findsOneWidget);
    expect(find.text('चावल'), findsWidgets);
    expect(find.text('गेहूं'), findsWidgets);
    expect(find.text('कुल मात्रा'), findsOneWidget);
    expect(find.text('यह आपकी इस वितरण चक्र के लिए पात्र मात्रा है।'), findsOneWidget);

    // Switch to Kannada
    LanguageController.instance.setLanguage(AppLanguage.kannada);
    await tester.pumpAndSettle();

    // Verify Kannada labels
    expect(find.text('ನಿಮ್ಮ ಕುಟುಂಬದ ಪಡಿತರ ಹಕ್ಕು'), findsWidgets);
    expect(find.text('ಕುಟುಂಬದ ಸದಸ್ಯರು: '), findsOneWidget);
    expect(find.text('ಅಕ್ಕಿ'), findsWidgets);
    expect(find.text('ಗೋಧಿ'), findsWidgets);
    expect(find.text('ಒಟ್ಟು ಪ್ರಮಾಣ'), findsOneWidget);
    expect(find.text('ಇದು ಈ ವಿತರಣಾ ಚಕ್ರಕ್ಕೆ ನಿಮ್ಮ ಅರ್ಹ ಪ್ರಮಾಣವಾಗಿದೆ.'), findsOneWidget);
  });

  testWidgets('4. Voice Assistant explains actual entitlement values naturally', (tester) async {
    VoiceAssistantService.instance.enableBeneficiaryVoiceMode();
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isTrue);

    // Test English readout with actual dataset values: 20kg total, 15kg rice, 5kg wheat
    LanguageController.instance.setLanguage(AppLanguage.english);
    VoiceAssistantService.instance.guideDemandEntitlement(
      totalKg: 20.0,
      riceKg: 15.0,
      wheatKg: 5.0,
      membersCount: 4,
    );
    await tester.pump(const Duration(seconds: 8));

    // Test Hindi readout with actual values
    LanguageController.instance.setLanguage(AppLanguage.hindi);
    VoiceAssistantService.instance.guideDemandEntitlement(
      totalKg: 20.0,
      riceKg: 15.0,
      wheatKg: 5.0,
      membersCount: 4,
    );
    await tester.pump(const Duration(seconds: 8));

    // Test Kannada readout with actual values
    LanguageController.instance.setLanguage(AppLanguage.kannada);
    VoiceAssistantService.instance.guideDemandEntitlement(
      totalKg: 20.0,
      riceKg: 15.0,
      wheatKg: 5.0,
      membersCount: 4,
    );
    await tester.pump(const Duration(seconds: 8));
  });
}
