import 'package:flutter_test/flutter_test.dart';
import 'package:pds_demandsync/services/beneficiary_voice_router.dart';

void main() {
  group('BeneficiaryVoiceCommandRouter Intent Tests', () {
    test('1. Demand / Grain Requirement in EN, HI, KN', () {
      final r1 = BeneficiaryVoiceCommandRouter.resolve('I need rice');
      expect(r1.intent, BeneficiaryVoiceIntent.demandSelection);
      expect(r1.grainType, 'RICE');

      final r2 = BeneficiaryVoiceCommandRouter.resolve('I need wheat');
      expect(r2.intent, BeneficiaryVoiceIntent.demandSelection);
      expect(r2.grainType, 'WHEAT');

      final r3 = BeneficiaryVoiceCommandRouter.resolve('What do I need next time?');
      expect(r3.intent, BeneficiaryVoiceIntent.demandSelection);

      final r4 = BeneficiaryVoiceCommandRouter.resolve('Select my ration');
      expect(r4.intent, BeneficiaryVoiceIntent.demandSelection);

      final r5 = BeneficiaryVoiceCommandRouter.resolve('मुझे राशन चाहिए');
      expect(r5.intent, BeneficiaryVoiceIntent.demandSelection);

      final r6 = BeneficiaryVoiceCommandRouter.resolve('चावल चाहिए');
      expect(r6.intent, BeneficiaryVoiceIntent.demandSelection);

      final r7 = BeneficiaryVoiceCommandRouter.resolve('ನನಗೆ ಪಡಿತರ ಬೇಕು');
      expect(r7.intent, BeneficiaryVoiceIntent.demandSelection);

      final r8 = BeneficiaryVoiceCommandRouter.resolve('ಅಕ್ಕಿ ಬೇಕು');
      expect(r8.intent, BeneficiaryVoiceIntent.demandSelection);
    });

    test('2. Ration Shop / FPS in EN, HI, KN', () {
      final r1 = BeneficiaryVoiceCommandRouter.resolve('My ration shop');
      expect(r1.intent, BeneficiaryVoiceIntent.rationShop);

      final r2 = BeneficiaryVoiceCommandRouter.resolve('Where is my ration shop?');
      expect(r2.intent, BeneficiaryVoiceIntent.rationShop);

      final r3 = BeneficiaryVoiceCommandRouter.resolve('Show my FPS');
      expect(r3.intent, BeneficiaryVoiceIntent.rationShop);

      final r4 = BeneficiaryVoiceCommandRouter.resolve('Which shop should I go to?');
      expect(r4.intent, BeneficiaryVoiceIntent.rationShop);

      final r5 = BeneficiaryVoiceCommandRouter.resolve('मेरी राशन दुकान');
      expect(r5.intent, BeneficiaryVoiceIntent.rationShop);

      final r6 = BeneficiaryVoiceCommandRouter.resolve('नक्शा दिखाओ');
      expect(r6.intent, BeneficiaryVoiceIntent.rationShop);

      final r7 = BeneficiaryVoiceCommandRouter.resolve('ನನ್ನ ಪಡಿತರ ಅಂಗಡಿ');
      expect(r7.intent, BeneficiaryVoiceIntent.rationShop);

      final r8 = BeneficiaryVoiceCommandRouter.resolve('ಅಂಗಡಿ ಎಲ್ಲಿದೆ');
      expect(r8.intent, BeneficiaryVoiceIntent.rationShop);
    });

    test('3. Tracking in EN, HI, KN', () {
      final r1 = BeneficiaryVoiceCommandRouter.resolve('Track my ration');
      expect(r1.intent, BeneficiaryVoiceIntent.tracking);

      final r2 = BeneficiaryVoiceCommandRouter.resolve('Where is my ration?');
      expect(r2.intent, BeneficiaryVoiceIntent.tracking);

      final r3 = BeneficiaryVoiceCommandRouter.resolve('Is my ration ready?');
      expect(r3.intent, BeneficiaryVoiceIntent.tracking);

      final r4 = BeneficiaryVoiceCommandRouter.resolve('Has my ration been delivered?');
      expect(r4.intent, BeneficiaryVoiceIntent.tracking);

      final r5 = BeneficiaryVoiceCommandRouter.resolve('राशन कहां पहुंचा');
      expect(r5.intent, BeneficiaryVoiceIntent.tracking);

      final r6 = BeneficiaryVoiceCommandRouter.resolve('ट्रैक राशन');
      expect(r6.intent, BeneficiaryVoiceIntent.tracking);

      final r7 = BeneficiaryVoiceCommandRouter.resolve('ಪಡಿತರ ಎಲ್ಲಿಗೆ ತಲುಪಿದೆ');
      expect(r7.intent, BeneficiaryVoiceIntent.tracking);

      final r8 = BeneficiaryVoiceCommandRouter.resolve('ಟ್ರ್ಯಾಕ್ ಪಡಿತರ');
      expect(r8.intent, BeneficiaryVoiceIntent.tracking);
    });

    test('4. Help / Problem in EN, HI, KN', () {
      final r1 = BeneficiaryVoiceCommandRouter.resolve('I have a problem');
      expect(r1.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r2 = BeneficiaryVoiceCommandRouter.resolve('I need help');
      expect(r2.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r3 = BeneficiaryVoiceCommandRouter.resolve('I did not receive my ration');
      expect(r3.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r4 = BeneficiaryVoiceCommandRouter.resolve('My ration is short');
      expect(r4.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r5 = BeneficiaryVoiceCommandRouter.resolve('I want to complain');
      expect(r5.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r6 = BeneficiaryVoiceCommandRouter.resolve('Give feedback');
      expect(r6.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r7 = BeneficiaryVoiceCommandRouter.resolve('मदद चाहिए');
      expect(r7.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r8 = BeneficiaryVoiceCommandRouter.resolve('शिकायत करनी है');
      expect(r8.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r9 = BeneficiaryVoiceCommandRouter.resolve('ಸಹಾಯ ಬೇಕು');
      expect(r9.intent, BeneficiaryVoiceIntent.helpFeedback);

      final r10 = BeneficiaryVoiceCommandRouter.resolve('ದೂರು ನೀಡಬೇಕು');
      expect(r10.intent, BeneficiaryVoiceIntent.helpFeedback);
    });

    test('5. Vending Machine in EN, HI, KN', () {
      final r1 = BeneficiaryVoiceCommandRouter.resolve('Get my ration');
      expect(r1.intent, BeneficiaryVoiceIntent.grainAtm);

      final r2 = BeneficiaryVoiceCommandRouter.resolve('Use vending machine');
      expect(r2.intent, BeneficiaryVoiceIntent.grainAtm);

      final r3 = BeneficiaryVoiceCommandRouter.resolve('Ration vending machine');
      expect(r3.intent, BeneficiaryVoiceIntent.grainAtm);

      final r4 = BeneficiaryVoiceCommandRouter.resolve('Where can I collect my ration?');
      expect(r4.intent, BeneficiaryVoiceIntent.grainAtm);

      final r5 = BeneficiaryVoiceCommandRouter.resolve('राशन वेंडिंग मशीन');
      expect(r5.intent, BeneficiaryVoiceIntent.grainAtm);

      final r6 = BeneficiaryVoiceCommandRouter.resolve('वेंडिंग मशीन');
      expect(r6.intent, BeneficiaryVoiceIntent.grainAtm);

      final r7 = BeneficiaryVoiceCommandRouter.resolve('ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್');
      expect(r7.intent, BeneficiaryVoiceIntent.grainAtm);

      final r8 = BeneficiaryVoiceCommandRouter.resolve('ವೆಂಡಿಂಗ್ ಮೆಷಿನ್');
      expect(r8.intent, BeneficiaryVoiceIntent.grainAtm);
    });

    test('6. History, Profile, and Language Switching', () {
      final rHist = BeneficiaryVoiceCommandRouter.resolve('Show history');
      expect(rHist.intent, BeneficiaryVoiceIntent.historyReceipts);

      final rProf = BeneficiaryVoiceCommandRouter.resolve('My profile');
      expect(rProf.intent, BeneficiaryVoiceIntent.profileCard);

      final rHi = BeneficiaryVoiceCommandRouter.resolve('Switch to Hindi');
      expect(rHi.intent, BeneficiaryVoiceIntent.languageHindi);

      final rKn = BeneficiaryVoiceCommandRouter.resolve('Switch to Kannada');
      expect(rKn.intent, BeneficiaryVoiceIntent.languageKannada);

      final rEn = BeneficiaryVoiceCommandRouter.resolve('Switch to English');
      expect(rEn.intent, BeneficiaryVoiceIntent.languageEnglish);
    });
  });
}
