import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/screens/beneficiary/demo_login_screen.dart';
import 'package:pds_demandsync/services/voice_assistant_service.dart';

void main() {
  setUp(() {
    VoiceAssistantService.instance.stopVoiceAssistantMode();
  });

  tearDown(() {
    VoiceAssistantService.instance.stopVoiceAssistantMode();
  });

  testWidgets('1. Initial Login Screen has zero Voice Assistant and zero mic controls', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DemoLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Voice assistant mode must be OFF
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isFalse);

    // Initial role selection view is visible
    expect(find.byKey(const ValueKey('initial_portal_selection')), findsOneWidget);

    // Citizen OTP & Department Official choices are visible
    expect(find.text('Citizen OTP / Beneficiary'), findsWidgets);
    expect(find.text('Department Official'), findsWidgets);

    // No microphone buttons on initial state
    expect(find.byIcon(Icons.mic_rounded), findsNothing);

    // No Voice Assistant active badge or banner
    expect(find.text('Voice Assistant (Active)'), findsNothing);
    expect(find.text('Tap to Speak 🎙️'), findsNothing);
  });

  testWidgets('2. Selecting Citizen OTP activates Voice Assistant without Tap to Speak button on login', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DemoLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Citizen OTP option card
    final citizenOption = find.text('Select Citizen Login');
    expect(citizenOption, findsOneWidget);
    await tester.tap(citizenOption);
    await tester.pumpAndSettle();

    // Voice assistant mode must be ON
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isTrue);

    // Voice Assistant Banner is displayed
    expect(find.byType(VoiceAssistantBanner), findsOneWidget);

    // EXACT REQUIREMENT: Tap to Speak must NOT appear on the login screen
    expect(find.text('Tap to Speak 🎙️'), findsNothing);

    // Speaker / replay control is present
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    // Citizen OTP form is displayed with field-level mic buttons
    expect(find.byKey(const ValueKey('citizen_otp')), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });

  testWidgets('3. Switching to Department Official immediately disables Voice Assistant', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DemoLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Select Citizen OTP first
    await tester.tap(find.text('Select Citizen Login'));
    await tester.pumpAndSettle();
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isTrue);
    expect(find.byType(VoiceAssistantBanner), findsOneWidget);

    // 2. Switch to Department Official tab in top segment
    final deptTab = find.widgetWithText(InkWell, 'Department Official');
    expect(deptTab, findsOneWidget);
    await tester.tap(deptTab);
    await tester.pumpAndSettle();

    // Voice assistant must be immediately OFF
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isFalse);

    // Voice assistant banner must be gone
    expect(find.text('Tap to Speak 🎙️'), findsNothing);
    expect(find.text('Voice Assistant (Active)'), findsNothing);

    // Department Official form is visible with NO mic buttons
    expect(find.byKey(const ValueKey('dept_login')), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
  });

  testWidgets('4. Switching back to Citizen OTP dynamically re-enables Voice Assistant without Tap to Speak', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DemoLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Department Official first
    await tester.tap(find.text('Select Official Login'));
    await tester.pumpAndSettle();
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isFalse);

    // Switch to Citizen OTP tab
    final citizenTab = find.widgetWithText(InkWell, 'Citizen OTP');
    expect(citizenTab, findsOneWidget);
    await tester.tap(citizenTab);
    await tester.pumpAndSettle();

    // Voice assistant must be ON again
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isTrue);
    expect(find.byType(VoiceAssistantBanner), findsOneWidget);
    // Tap to Speak must NOT appear on login
    expect(find.text('Tap to Speak 🎙️'), findsNothing);
    expect(find.byKey(const ValueKey('citizen_otp')), findsOneWidget);
  });

  testWidgets('5. VoiceAssistantBanner retains Tap to Speak for post-login screens (Beneficiary Home)', (tester) async {
    VoiceAssistantService.instance.enableBeneficiaryVoiceMode();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceAssistantBanner(), // Default showTapToSpeak is true
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap to Speak MUST be present when showTapToSpeak defaults to true
    expect(find.text('Tap to Speak 🎙️'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });
}
