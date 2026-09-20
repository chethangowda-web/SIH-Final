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

  testWidgets('1. Initial Login Screen has zero Voice Assistant banners and zero voice-login cards', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: DemoLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Voice assistant mode must be OFF on login screen
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isFalse);

    // Initial role selection view is visible
    expect(find.byKey(const ValueKey('initial_portal_selection')), findsOneWidget);

    // Citizen OTP & Department Official choices are visible
    expect(find.text('Citizen OTP / Beneficiary'), findsWidgets);
    expect(find.text('Department Official'), findsWidgets);

    // No microphone buttons on initial selection view
    expect(find.byIcon(Icons.mic_rounded), findsNothing);

    // No Voice Assistant active banner or One-Touch Voice Login card
    expect(find.text('Voice Assistant (Active)'), findsNothing);
    expect(find.text('One-Touch Voice Login (Speak)'), findsNothing);
    expect(find.text('Tap to Speak 🎙️'), findsNothing);
  });

  testWidgets('2. Selecting Citizen OTP displays form with in-field mic icons and zero voice banners/cards', (tester) async {
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

    // Voice assistant mode remains OFF on login screen
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isFalse);

    // Voice Assistant Banner must NOT appear on login screen
    expect(find.byType(VoiceAssistantBanner), findsNothing);
    expect(find.text('One-Touch Voice Login (Speak)'), findsNothing);
    expect(find.text('Tap to Speak 🎙️'), findsNothing);

    // Citizen OTP form is displayed with in-field mic buttons (for accessibility input assistance)
    expect(find.byKey(const ValueKey('citizen_otp')), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });

  testWidgets('3. Switching to Department Official displays form with zero mic buttons', (tester) async {
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

    // 2. Switch to Department Official tab in top segment
    final deptTab = find.widgetWithText(InkWell, 'Department Official');
    expect(deptTab, findsOneWidget);
    await tester.tap(deptTab);
    await tester.pumpAndSettle();

    // Voice assistant must be OFF
    expect(VoiceAssistantService.instance.isVoiceAssistantMode, isFalse);
    expect(find.text('Tap to Speak 🎙️'), findsNothing);
    expect(find.text('Voice Assistant (Active)'), findsNothing);

    // Department Official form is visible with NO mic buttons
    expect(find.byKey(const ValueKey('dept_login')), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
  });

  testWidgets('4. VoiceAssistantBanner retains Tap to Speak for post-login screens (Beneficiary Home)', (tester) async {
    VoiceAssistantService.instance.enableBeneficiaryVoiceMode();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceAssistantBanner(), // Default showTapToSpeak is true
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap to Speak MUST be present when showTapToSpeak defaults to true for authenticated screens
    expect(find.text('Tap to Speak 🎙️'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });
}
