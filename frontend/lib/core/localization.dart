import 'package:flutter/material.dart';
import 'constants.dart';

enum AppLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'Hindi', 'हिंदी'),
  kannada('kn', 'Kannada', 'ಕನ್ನಡ');

  final String code;
  final String englishName;
  final String nativeName;

  const AppLanguage(this.code, this.englishName, this.nativeName);

  static AppLanguage fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'hi':
        return AppLanguage.hindi;
      case 'kn':
        return AppLanguage.kannada;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }
}

class LanguageController extends ChangeNotifier {
  LanguageController._();
  static final LanguageController instance = LanguageController._();

  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;

  void setLanguage(AppLanguage language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
    }
  }

  void setLanguageByCode(String code) {
    setLanguage(AppLanguage.fromCode(code));
  }

  String translate(String key, {Map<String, String>? params}) {
    final langCode = _currentLanguage.code;
    final dict = _translations[langCode] ?? _translations['en']!;
    String text = dict[key] ?? _translations['en']![key] ?? key;

    if (params != null) {
      params.forEach((paramKey, paramValue) {
        text = text.replaceAll('{$paramKey}', paramValue);
      });
    }

    return text;
  }
}

// Global helper function for concise translation calls
String tr(String key, {Map<String, String>? params}) {
  return LanguageController.instance.translate(key, params: params);
}

// Centralized Translation Dictionary
const Map<String, Map<String, String>> _translations = {
  'en': {
    // General & Brand
    'app.name': 'PDS DemandSync',
    'app.subtitle': 'Forward-Looking Beneficiary Intent for Pre-Dispatch PDS Demand Forecasting',
    'app.gov_badge': 'GOVT. OF KARNATAKA • BENGALURU URBAN PDS PILOT',
    'app.dashboard': 'Citizen Beneficiary Portal',
    'app.nfsa_notice': 'National Food Security Act • Public Distribution Portal',
    'app.cycle_label': 'September 2026 (Cycle 7)',

    // Language Selector
    'lang.selector_title': 'Language / भाषा / ಭಾಷೆ',
    'lang.english': 'English',
    'lang.hindi': 'हिंदी',
    'lang.kannada': 'ಕನ್ನಡ',

    // Login Screen
    'login.officer_portal_title': 'District Supply Operations Portal',
    'login.officer_portal_subtitle': 'Department of Food & Civil Supplies • Bengaluru Urban',
    'login.officer_btn': 'District Supply Officer — Bengaluru Urban',
    'login.officer_authenticating': 'Authenticating Officer Session...',
    'login.citizen_portal_title': 'Beneficiary Portal Sign-In',
    'login.citizen_portal_subtitle': 'Select a citizen profile to simulate forward-looking intent',
    'login.select_profile': 'SELECT BENEFICIARY PROFILE',
    'login.continue_btn': 'Continue as Beneficiary',
    'login.authenticating': 'Authenticating Beneficiary...',
    'login.swathi_role': 'Resident Beneficiary • Home FPS Collector',
    'login.sunita_role': 'Migrant Construction Worker • High Portability Surge',
    'login.ramesh_role': 'Industrial Sector Beneficiary • Shift Worker',
    'login.system_diagnostics': 'View System Diagnostics & Pipeline Flow',

    // Beneficiary Profile
    'profile.title': 'Registered Citizen Profile',
    'profile.fps_label': 'Registered Fair Price Shop',
    'profile.family_members': 'Family Members',
    'profile.status_active': 'ACTIVE & VERIFIED',
    'profile.card_type': 'Card Type: {type}',
    'profile.loading': 'Loading verified government entitlement record...',
    'profile.error_retry': 'Try Again',

    // Commodities & Units
    'commodity.rice': 'Rice',
    'commodity.wheat': 'Wheat',
    'commodity.kg': 'kg',
    'commodity.free_tag': '100% Free',
    'commodity.entitled_free': '100% Free',

    // Statutory Entitlement Card
    'entitlement.title': 'YOUR RATION ENTITLEMENT',
    'entitlement.non_editable': 'NON-EDITABLE',
    'entitlement.monthly_quota': 'Monthly Quota',
    'entitlement.consumed': 'Consumed this Cycle',
    'entitlement.remaining_balance': 'AVAILABLE REMAINING BALANCE',
    'entitlement.statutory_rule': 'Your ration entitlement is determined by government policy. You cannot increase or customize the quantity.',

    // Service Choice Section
    'service.plan_title': 'PLAN YOUR UPCOMING COLLECTION',
    'service.plan_subtitle': 'Express your preference in advance so supply is prepared before depot dispatch',
    'service.fps_choice_title': 'Collect at Fair Price Shop',
    'service.fps_choice_desc': 'Self-pickup from your registered home shop or any nearby FPS under One Nation One Ration Card.',
    'service.fps_choice_detail': 'Designated center: {fpsName}',
    'service.fps_choice_badge': 'FREE PICKUP',
    'service.fps_choice_price': 'Free of Charge (₹0.00)',
    'service.fps_choice_btn': 'Select Shop',
    'service.home_choice_title': 'Assisted Home Delivery',
    'service.home_choice_desc': 'Authorized last-mile delivery partner delivers sealed ration to your residential address.',
    'service.home_choice_detail': 'Delivery Address: Bengaluru Urban',
    'service.home_choice_badge': 'DOORSTEP SERVICE',
    'service.home_choice_price': 'Logistics Fee: ₹87.50',
    'service.home_choice_btn': 'Choose Delivery',

    // Order & Delivery Tracking
    'delivery.section_title': 'CURRENT REQUEST / DELIVERY STATUS',
    'delivery.order_num': 'Order #{orderId}',
    'delivery.timeline_requested': 'Requested',
    'delivery.timeline_allocated': 'Allocated',
    'delivery.timeline_out_for_delivery': 'Out for Delivery',
    'delivery.timeline_delivered': 'Delivered',
    'delivery.timeline_confirmed': 'Confirmed',
    'delivery.authorized_commodities': 'AUTHORIZED RATION COMMODITIES',
    'delivery.mode_home': 'HOME DELIVERY',
    'delivery.mode_fps': 'FPS COLLECTION',
    'delivery.logistics_fee': 'Logistics Fee: ₹{fee}',
    'delivery.pickup_location': 'Pickup: {fpsName}',
    'delivery.delivery_address': 'Address: {address}',
    'delivery.did_you_receive': 'Did you receive your ration?',
    'delivery.btn_confirm_full': 'Yes, I received full quantity',
    'delivery.btn_report_issue': 'Report quantity issue',
    'delivery.confirm_success': 'Delivery confirmed! Digital receipt registered with district supply office for complete ration quota.',
    'delivery.dispute_reason_banner': 'Dispute Reason: {reason} (Under DSO Investigation)',

    // Delivery Dispute Modal
    'dispute.modal_title': 'Report Delivery Discrepancy',
    'dispute.order_ref': 'Order #{orderId} • Authorized: {quota}',
    'dispute.detected_shortfall': 'Detected Shortfall:',
    'dispute.rice_shortfall': '• Rice Shortfall: {qty} kg deficit',
    'dispute.wheat_shortfall': '• Wheat Shortfall: {qty} kg deficit',
    'dispute.actual_rice_label': 'Actual Rice Received (kg) • Authorized: {expected} kg',
    'dispute.actual_wheat_label': 'Actual Wheat Received (kg) • Authorized: {expected} kg',
    'dispute.remarks_label': 'Discrepancy Details / Remarks',
    'dispute.remarks_hint': 'e.g. Weighment deficit, damaged packaging, missing items',
    'dispute.btn_submit': 'Submit Formal Dispute to DSO Queue',
    'dispute.submitting': 'Submitting Dispute...',
    'dispute.success': 'Dispute recorded. Submitted to District Supply Officer (DSO) for inquiry.',

    // History Section
    'history.title': 'Declared Intent Signal History',
    'history.view_timeline': 'View All Timeline →',
    'history.empty': 'You have not submitted any forward-looking intent declarations for upcoming cycles yet.',
    'history.screen_title': 'Declared Intent Signal History',
    'history.screen_subtitle': 'PDS DemandSync • Forward-Looking Supply Planning Records',
    'history.timeline_header': 'Chronological Intent Signals',
    'history.intended_fps_label': 'INTENDED TARGET FPS',
    'history.no_signals': 'No Intent Signals Found',

    // Intent Selection Screen
    'intent.screen_title': 'Express Collection Preference',
    'intent.step_service': 'Service Mode',
    'intent.step_fps': 'Location / FPS',
    'intent.step_review': 'Review',
    'intent.step_confirm': 'Confirmation',
    'intent.section1_title': 'HOW WOULD YOU LIKE TO RECEIVE YOUR RATION?',
    'intent.fps_choice_title': 'Collect from Fair Price Shop',
    'intent.home_choice_title': 'Assisted Home Delivery',
    'intent.section2_title': 'CHOOSE YOUR INTENDED FAIR PRICE SHOP',
    'intent.fps_search_hint': 'Search center name or FPS code...',
    'intent.home_fps_tag': 'Home FPS',
    'intent.portability_tag': 'PORTABILITY SHIFT',
    'intent.section3_title': 'HOME DELIVERY ADDRESS & LOGISTICS',
    'intent.address_label': 'Delivery Address in Bengaluru Urban',
    'intent.distance_label': 'Distance from Nearest Depot/FPS: {dist} km',
    'intent.logistics_breakdown': 'Logistics Breakdown: Base ₹20.00 + Distance Surcharge = ₹{fee}',
    'intent.section4_title': 'YOUR STATUTORY ENTITLEMENT SUMMARY',
    'intent.btn_continue': 'Continue to Review & Confirm',
    'intent.btn_continue_fps': 'Continue to Review FPS Collection (₹0.00 Free)',
    'intent.btn_continue_home': 'Continue to Review Home Delivery (₹{fee})',
    'intent.policy_footer': 'FOODGRAINS ARE 100% SUBSIDIZED (₹0.00/KG) • DECLARING INTENT PREVENTS STOCKOUTS',

    // Intent Confirmation Screen
    'confirm.review_title': 'Review Your Collection Plan',
    'confirm.review_subtitle': 'Please verify your collection preferences before submitting to the district dispatch engine.',
    'confirm.success_heading': 'Collection Plan Submitted',
    'confirm.success_desc': 'Your collection preference has been successfully ingested into the PDS pre-dispatch intelligence engine.',
    'confirm.gov_notice_title': 'IMPORTANT GOVERNANCE NOTICE',
    'confirm.gov_notice_desc': 'Your entitlement is determined by government policy. This request does not increase, decrease, or modify your statutory entitlement.',
    'confirm.gov_transport_note': 'Only transportation/logistics charges are payable.',
    'confirm.what_next_title': 'WHAT HAPPENS NEXT',
    'confirm.you_pay': 'TOTAL PAYABLE / YOU PAY',
    'confirm.step1_title': 'Request recorded',
    'confirm.step1_desc': 'Your preferred pickup channel is logged into the district pre-dispatch intelligence engine.',
    'confirm.step2_title': 'Government allocation review',
    'confirm.step2_desc': 'District Supply Office verifies buffer stock and schedules vehicle dispatch.',
    'confirm.step3_title': 'Allocation confirmed',
    'confirm.step3_desc': 'Target Fair Price Shop / delivery fleet receives pre-positioned grain buffer.',
    'confirm.step4_title': 'Delivery / collection',
    'confirm.step4_desc': 'Ration is delivered to your doorstep or ready for seamless counter pickup.',
    'confirm.step5_title': 'Citizen confirms receipt',
    'confirm.step5_desc': 'You verify grain quantity and confirm full receipt on your digital portal.',
    'confirm.btn_submit_plan': 'Submit Collection Plan',
    'confirm.btn_submitting': 'Submitting Plan...',
    'confirm.btn_go_back': 'Go Back & Edit Options',
    'confirm.receipt_title': 'DIGITAL PREFERENCE RECEIPT',
    'confirm.receipt_next_step': 'NEXT STEP',
    'confirm.receipt_next_step_desc': 'District Supply Office is aggregating demand signals for cycle allocation. You will receive an SMS and portal update once stock is staged.',
    'confirm.btn_view_portal': 'View Status in Citizen Portal',
    'confirm.btn_view_history': 'View All Ingested Signals',

    // Household Members & Calculation
    'members.title': 'ELIGIBLE HOUSEHOLD MEMBERS',
    'members.badge': '5.0 kg / ELIGIBLE PERSON',
    'members.subtitle': 'Number of household members eligible for foodgrain under statutory ration entitlement',
    'members.formula': '{count} Members × 5.0 kg = {max} kg Maximum Household Quota',
    'members.allocation_title': 'COMBINED FOODGRAIN ALLOCATION',
    'members.rice_alloc': 'Fortified Rice Allocation',
    'members.wheat_alloc': 'Whole Wheat Allocation',
    'members.over_error': 'Combined requested quantity ({qty} kg) exceeds the maximum household entitlement ({max} kg) for {count} eligible members.',
    'members.adjust_hint': 'Adjust quantities to stay within your statutory entitlement ceiling.',

    // Biometric & Delivery Verification
    'biometric.title_fps': 'FPS COUNTER BIOMETRIC VERIFICATION',
    'biometric.title_home': 'DOORSTEP BIOMETRIC VERIFICATION',
    'biometric.check_heading': '3-POINT DIAGNOSTIC ELIGIBILITY CHECKS:',
    'biometric.check1': 'Beneficiary Aadhaar Identity Match (Mock ePoS Scanner)',
    'biometric.check2': 'Ration Card Active & Non-Suspended (Dept Registry)',
    'biometric.check3': 'Unlifted Foodgrain Quota Available ({qty} kg Eligible)',
    'biometric.status_initial': 'READY FOR THUMB VERIFICATION',
    'biometric.status_scanning': 'COMMUNICATING WITH ePoS / AADHAAR SERVER...',
    'biometric.status_verified': 'VERIFICATION SUCCESSFUL • AUTHORIZED',
    'biometric.status_failed': 'BIOMETRIC FAILED • DISTRIBUTION LOCKED',
    'biometric.status_distributed': 'FOODGRAIN DISTRIBUTED & LOGGED',
    'biometric.desc_initial': 'Place beneficiary or authorized family member thumb on the scanner to authenticate delivery handover.',
    'biometric.desc_scanning': 'Matching biometric minutiae against cryptographic UIDAI template token...',
    'biometric.desc_verified': 'Identity, Ration Card status, and Entitlement Quota verified. Ready for physical grain release.',
    'biometric.desc_failed': 'Fingerprint pattern does not match registered beneficiary database record.',
    'biometric.desc_distributed': 'Physical handover complete. Statutory balance updated in central PDS ledger.',
    'biometric.btn_simulate_match': 'Simulate Thumb Match (Success)',
    'biometric.btn_simulate_mismatch': 'Simulate Mismatch (Failure)',
    'biometric.btn_retry': 'Retry Fingerprint Scan',
    'biometric.btn_authorize': 'Authorize & Distribute Foodgrain',
    'biometric.btn_completed': 'Done / Close Receipt',
    'biometric.summary_entitlement': 'Monthly Entitlement: {max} kg',
    'biometric.summary_distributed': 'Distributed: {dist} kg',
    'biometric.summary_remaining': 'Remaining: {rem} kg',
    'biometric.btn_verify_fps': 'Verify Biometrics & Receive Foodgrain',
    'biometric.btn_verify_home': 'Verify Biometrics & Confirm Delivery',
    'biometric.fps_banner': 'Thumb biometric verification required at Fair Price Shop counter before ration handover.',
    'biometric.doorstep_banner': 'Thumb biometric verification required upon delivery agent arrival before grain distribution.',
    'biometric.distributed_badge': 'DISTRIBUTED VIA BIOMETRIC AUTH',

    // Pre-Dispatch Decision Pipeline & Live Timers
    'predispatch.modal_title': 'Pre-Dispatch Decision Intelligence Analysis',
    'predispatch.running': 'Running Pre-Dispatch Decision Pipeline...',
    'predispatch.completed_all': 'Pre-Dispatch Analysis Execution Complete',
    'predispatch.stage_forecast': '1. FORECAST',
    'predispatch.stage_validate': '2. VALIDATE',
    'predispatch.stage_optimize': '3. OPTIMIZE',
    'predispatch.stage_manifest': '4. MANIFEST',
    'predispatch.forecast_desc': 'Aggregating citizen intents & multi-factor composite demand (D̂)',
    'predispatch.validate_desc': 'Auditing 9 statutory floors, buffer stocks & invariant constraints',
    'predispatch.optimize_desc': 'Computing multi-stop TSP corridors & dynamic fleet scheduling',
    'predispatch.manifest_desc': 'Sealing cryptographic SHA-256 digital gatepass & allocations',
    'predispatch.scenario_normal': 'Scenario A: Stock Available (Normal Dispatch)',
    'predispatch.scenario_shortage': 'Scenario B: Government Stock Shortage (1–2 Day Temporary Delay)',
    'predispatch.btn_run': 'Execute Pre-Dispatch Analysis',
    'predispatch.btn_proceed_dispatch': 'Lock Manifest & Proceed to Fleet Dispatch',
    'predispatch.btn_delay_dispatch': 'Delay Dispatch (1–2 Days) & Notify Beneficiaries',
    'predispatch.btn_resume_dispatch': 'Resume Dispatch (Stock Replenished)',
    'predispatch.stock_warning_title': '⚠️ Stock Constraint Detected',
    'predispatch.stock_warning_desc': 'Government stock currently unavailable for this dispatch. Expected replenishment delay is 1–2 days.',
    'predispatch.policy_notice': 'GOVERNMENT POLICY: Stock shortage represents a temporary delay, NOT a cancellation or rejection. Existing citizen orders remain 100% active.',

    // Temporary Stock Shortage Delay
    'delay.banner_title': '⏳ Delivery Delayed',
    'delay.banner_desc': 'Your ration delivery is temporarily delayed due to government stock availability. It is expected to be completed within 1–2 days.',
    'delay.badge': 'DELAYED — STOCK REPLENISHMENT PENDING',
    'delay.reason_label': 'Delay Reason',
    'delay.reason_stock': 'Government stock availability',
    'delay.expected_label': 'Expected Completion',
    'delay.expected_window': 'Within 1–2 Days',
    'delay.no_resubmit_hint': 'You do not need to submit your request again. Your allocation remains secured.',
    'delay.officer_notify_title': 'Notify Beneficiary of Temporary Stock Delay',
    'delay.officer_msg_template': 'Your ration delivery has been temporarily delayed because government stock is currently unavailable. The delivery is expected within 1–2 days. You do not need to submit the request again.',
    'delay.btn_send_alert': 'Send Delay Alert (SMS / WhatsApp)',
    'delay.alert_sent_success': 'Official stock shortage delay alert dispatched to beneficiary via SMS.',

    // Navigation & Common
    'nav.logout': 'Logout',
    'nav.back': 'Back',
    'nav.close': 'Close',
    'nav.cancel': 'Cancel',
    'nav.refresh': 'Refresh',
  },

  'hi': {
    // General & Brand
    'app.name': 'पीडीएस डिमांडसिंक (PDS DemandSync)',
    'app.subtitle': 'सार्वजनिक वितरण प्रणाली हेतु प्रेषण-पूर्व मांग पूर्वानुमान एवं नागरिक समन्वय',
    'app.gov_badge': 'कर्नाटक सरकार • बेंगलुरु शहरी पीडीएस पायलट',
    'app.dashboard': 'राशन कार्ड डैशबोर्ड',
    'app.nfsa_notice': 'राष्ट्रीय खाद्य सुरक्षा अधिनियम (NFSA 2013) • सार्वजनिक वितरण पोर्टल',
    'app.cycle_label': 'चक्र 7 · सितंबर 2026',

    // Language Selector
    'lang.selector_title': 'भाषा / Language / ಭಾಷೆ',
    'lang.english': 'English',
    'lang.hindi': 'हिंदी',
    'lang.kannada': 'ಕನ್ನಡ',

    // Login Screen
    'login.officer_portal_title': 'जिला आपूर्ति संचालन पोर्टल',
    'login.officer_portal_subtitle': 'खाद्य एवं नागरिक आपूर्ति विभाग • बेंगलुरु शहरी',
    'login.officer_btn': 'जिला आपूर्ति अधिकारी (DSO) — बेंगलुरु शहरी',
    'login.officer_authenticating': 'अधिकारी सत्र प्रमाणीकरण जारी है...',
    'login.citizen_portal_title': 'लाभार्थी नागरिक पोर्टल लॉगिन',
    'login.citizen_portal_subtitle': 'आगामी राशन चक्र के लिए अपनी प्रोफाइल चुनें',
    'login.select_profile': 'लाभार्थी प्रोफाइल का चयन करें',
    'login.continue_btn': 'लाभार्थी के रूप में आगे बढ़ें',
    'login.authenticating': 'लाभार्थी प्रमाणीकरण जारी है...',
    'login.swathi_role': 'स्थानीय निवासी लाभार्थी • मूल राशन दुकान संग्रहकर्ता',
    'login.sunita_role': 'प्रवासी निर्माण श्रमिक • पोर्टेबिलिटी प्राथमिकता',
    'login.ramesh_role': 'औद्योगिक क्षेत्र लाभार्थी • शिफ्ट श्रमिक',
    'login.system_diagnostics': 'सिस्टम निदान एवं पाइपलाइन प्रवाह देखें',

    // Beneficiary Profile
    'profile.title': 'सत्यापित नागरिक प्रोफाइल',
    'profile.fps_label': 'पंजीकृत उचित मूल्य दुकान (FPS)',
    'profile.family_members': 'परिवार के सदस्य',
    'profile.status_active': 'सक्रिय एवं सत्यापित',
    'profile.card_type': 'कार्ड प्रकार: {type}',
    'profile.loading': 'सरकारी पात्रता रिकॉर्ड लोड हो रहा है...',
    'profile.error_retry': 'पुनः प्रयास करें',

    // Commodities & Units
    'commodity.rice': 'चावल',
    'commodity.wheat': 'गेहूं',
    'commodity.kg': 'कि.ग्रा.',
    'commodity.free_tag': '100% निःशुल्क',
    'commodity.entitled_free': '100% निःशुल्क',

    // Statutory Entitlement Card
    'entitlement.title': 'आपकी राशन पात्रता',
    'entitlement.non_editable': 'अपरिवर्तनीय',
    'entitlement.monthly_quota': 'मासिक कोटा',
    'entitlement.consumed': 'इस चक्र में प्राप्त राशन',
    'entitlement.remaining_balance': 'उपलब्ध शेष राशन शेष',
    'entitlement.statutory_rule': 'आपकी राशन पात्रता सरकारी नीति द्वारा निर्धारित है। आप मात्रा में वृद्धि या बदलाव नहीं कर सकते।',

    // Service Choice Section
    'service.plan_title': 'आगामी राशन संग्रह की योजना बनाएं',
    'service.plan_subtitle': 'अपनी प्राथमिकता पहले बताएं ताकि गोदाम से ट्रक रवाना होने से पहले अनाज तैयार हो सके',
    'service.fps_choice_title': 'उचित मूल्य दुकान से प्राप्त करें',
    'service.fps_choice_desc': 'अपनी पंजीकृत दुकान अथवा नजदीकी किसी भी पीडीएस केंद्र से स्वयं राशन प्राप्त करें।',
    'service.fps_choice_detail': 'नामित केंद्र: {fpsName}',
    'service.fps_choice_badge': 'निःशुल्क संग्रह',
    'service.fps_choice_price': 'पूर्णतः निःशुल्क (₹0.00)',
    'service.fps_choice_btn': 'दुकान चुनें',
    'service.home_choice_title': 'घर पर राशन डिलीवरी',
    'service.home_choice_badge': 'सुविधाजनक सेवा',
    'service.home_choice_desc': 'वरिष्ठ नागरिकों और सुविधा हेतु आपके घर तक सीधे सुरक्षित राशन वितरण।',
    'service.home_choice_detail': 'नाममात्र परिवहन एवं संवहन शुल्क लागू',
    'service.home_choice_price': 'परिवहन शुल्क: ₹20.00 बेस + ₹5/किमी',
    'service.home_choice_btn': 'डिलीवरी चुनें',

    // Delivery Status Timeline
    'delivery.section_title': 'वर्तमान ऑर्डर एवं वितरण स्थिति',
    'delivery.order_num': 'ऑर्डर #{orderId}',
    'delivery.authorized_commodities': 'अधिकृत खाद्यान्न आवंटन',
    'delivery.mode_fps': 'उचित मूल्य दुकान पिकअप',
    'delivery.mode_home': 'डोरस्टेप डिलीवरी',
    'delivery.delivery_address': 'डिलीवरी पता: {address}',
    'delivery.pickup_location': 'संग्रह केंद्र: {fpsName}',
    'delivery.logistics_fee': 'लॉजिस्टिक्स शुल्क: ₹{fee}',
    'delivery.did_you_receive': 'क्या आपको अपना पूरा राशन प्राप्त हुआ?',
    'delivery.btn_confirm_full': 'पूरा राशन प्राप्त हुआ (दೃढ़ीकरण)',
    'delivery.btn_report_issue': 'समस्या / विवाद दर्ज करें',
    'delivery.dispute_reason_banner': 'दर्ज विवाद: {reason}',

    // Intent Selection Screen
    'intent.screen_title': 'वितरण प्राथमिकता का चयन करें',
    'intent.step_service': 'सेवा चयन',
    'intent.step_fps': 'FPS केंद्र',
    'intent.step_review': 'समीक्षा',
    'intent.step_confirm': 'पुष्टि',
    'intent.section1_title': 'आप राशन कैसे प्राप्त करना चाहते हैं?',
    'intent.section1_subtitle': 'दुकान से संग्रह या सीधे घर तक डिलीवरी चुनें',
    'intent.fps_choice_title': 'उचित मूल्य दुकान (FPS)',
    'intent.home_choice_title': 'असिस्टेड डोरस्टेप डिलीवरी',
    'intent.section2_title': 'संग्रह हेतु उचित मूल्य दुकान चुनें',
    'intent.fps_search_hint': 'दुकान का नाम, क्षेत्र या FPS आईडी खोजें...',
    'intent.home_fps_tag': 'पंजीकृत दुकान',
    'intent.portability_tag': 'पोर्टेबिलिटी केंद्र',
    'intent.section3_title': 'डोरस्टेप डिलीवरी लॉजिस्टिक्स विवरण',
    'intent.address_label': 'डिलीवरी पता दर्ज करें',
    'intent.section4_title': 'आपका वैधानिक राशन कोटा सारांश',
    'intent.btn_continue': 'समीक्षा एवं पुष्टि हेतु आगे बढ़ें',
    'intent.btn_continue_fps': 'FPS संग्रह समीक्षा हेतु आगे बढ़ें (₹0.00 मुफ़्त)',
    'intent.btn_continue_home': 'डोरस्टेप समीक्षा हेतु आगे बढ़ें (₹{fee})',
    'intent.policy_footer': 'खाद्यान्न 100% मुफ़्त है (₹0.00/किग्रा) • प्राथमिकता बताने से स्टॉक की कमी नहीं होती',

    // Intent Confirmation Screen
    'confirm.review_title': 'अपनी संग्रह योजना की समीक्षा करें',
    'confirm.review_subtitle': 'जिला प्रेषण प्रणाली में सबमिट करने से पहले अपनी प्राथमिकताओं की जांच करें।',
    'confirm.success_heading': 'संग्रह योजना सबमिट हो गई',
    'confirm.success_desc': 'आपकी संग्रह प्राथमिकता पीडीएस प्रेषण-पूर्व इंजन में दर्ज कर ली गई है।',
    'confirm.gov_notice_title': 'महत्वपूर्ण सरकारी सूचना',
    'confirm.gov_notice_desc': 'आपका कोटा सरकारी नीति द्वारा निर्धारित है। यह अनुरोध आपके वैधानिक कोटे को नहीं बदलता।',
    'confirm.gov_transport_note': 'केवल डोरस्टेप परिवहन/संवहन शुल्क देय है।',
    'confirm.what_next_title': 'आगे क्या होगा',
    'confirm.you_pay': 'TOTAL PAYABLE / YOU PAY',
    'confirm.step1_title': 'अनुरोध दर्ज',
    'confirm.step1_desc': 'आपकी प्राथमिकता जिला प्रेषण प्रणाली में दर्ज हो गई है।',
    'confirm.step2_title': 'सरकारी समीक्षा',
    'confirm.step2_desc': 'आपूर्ति कार्यालय बफर स्टॉक की समीक्षा कर वाहन प्रेषण तय करता है।',
    'confirm.step3_title': 'आवंटन सुनिश्चित',
    'confirm.step3_desc': 'उचित मूल्य दुकान या डिलीवरी वाहन को आवश्यक स्टॉक प्राप्त होता है।',
    'confirm.step4_title': 'वितरण / संग्रह',
    'confirm.step4_desc': 'राशन आपके घर पहुंचता है या दुकान पर संग्रह हेतु तैयार रहता है।',
    'confirm.step5_title': 'नागरिक रसीद पुष्टि',
    'confirm.step5_desc': 'आप डिजिटल पोर्टल पर राशन मात्रा की पुष्टि करते हैं।',
    'confirm.btn_submit_plan': 'संग्रह योजना सबमिट करें',
    'confirm.btn_submitting': 'सबमिट किया जा रहा है...',
    'confirm.btn_go_back': 'पीछे जाएं एवं विकल्प बदलें',
    'confirm.receipt_title': 'डिजिटल प्राथमिकता रसीद',
    'confirm.receipt_next_step': 'अगला कदम',
    'confirm.receipt_next_step_desc': 'जिला आपूर्ति कार्यालय मांग संकेतों को एकत्रित कर रहा है। स्टॉक तैयार होने पर एसएमएस प्राप्त होगा।',
    'confirm.btn_view_portal': 'नागरिक पोर्टल पर स्थिति देखें',
    'confirm.btn_view_history': 'सभी दर्ज प्राथमिकताएं देखें',

    // Household Members & Calculation
    'members.title': 'पात्र परिवार के सदस्य',
    'members.badge': '5.0 किग्रा / पात्र व्यक्ति',
    'members.subtitle': 'सांविधिक राशन पात्रता के अंतर्गत खाद्यान्न हेतु पात्र परिवार के सदस्यों की संख्या',
    'members.formula': '{count} सदस्य × 5.0 किग्रा = {max} किग्रा अधिकतम पारिवारिक कोटा',
    'members.allocation_title': 'संयुक्त खाद्यान्न आवंटन',
    'members.rice_alloc': 'फोर्टिफाइड चावल आवंटन',
    'members.wheat_alloc': 'गेहूं आवंटन',
    'members.over_error': 'कुल मांगी गई मात्रा ({qty} किग्रा) {count} पात्र सदस्यों हेतु अधिकतम पारिवारिक पात्रता ({max} किग्रा) से अधिक है।',
    'members.adjust_hint': 'अपनी कानूनी सीमा के भीतर रहने हेतु मात्रा को समायोजित करें।',

    // Biometric & Delivery Verification
    'biometric.title_fps': 'उचित मूल्य दुकान बायोमेट्रिक सत्यापन',
    'biometric.title_home': 'डोरस्टेप बायोमेट्रिक सत्यापन',
    'biometric.check_heading': '3-बिंदु नैदानिक पात्रता जांच:',
    'biometric.check1': 'लाभार्थी आधार पहचान मिलान (सिम्युलेटेड ePoS स्कैनर)',
    'biometric.check2': 'राशन कार्ड सक्रिय एवं गैर-निलंबित (विभागीय रजिस्ट्री)',
    'biometric.check3': 'उपलब्ध शेष राशन कोटा ({qty} किग्रा पात्र)',
    'biometric.status_initial': 'अंगूठा सत्यापन हेतु तैयार',
    'biometric.status_scanning': 'ePoS / आधार सर्वर से संपर्क जारी...',
    'biometric.status_verified': 'सत्यापन सफल • अधिकृत',
    'biometric.status_failed': 'बायोमेट्रिक विफल • वितरण अवरुद्ध',
    'biometric.status_distributed': 'खाद्यान्न वितरित एवं दर्ज',
    'biometric.desc_initial': 'वितरण सौंपने हेतु लाभार्थी का अंगूठा स्कैनर पर लगाएं।',
    'biometric.desc_scanning': 'बायोमेट्रिक विवरण का मिलान किया जा रहा है...',
    'biometric.desc_verified': 'पहचान, राशन कार्ड स्थिति और कोटा सत्यापित। अनाज वितरण हेतु तैयार।',
    'biometric.desc_failed': 'अंगूठे का निशान डेटाबेस रिकॉर्ड से मेल नहीं खाता है।',
    'biometric.desc_distributed': 'भौतिक वितरण पूर्ण। केंद्रीय पीडीएस बहीखाते में शेष राशन अद्यतन।',
    'biometric.btn_simulate_match': 'अंगूठा मिलान सिम्युलेट करें (सफल)',
    'biometric.btn_simulate_mismatch': 'असंगत सिम्युलेट करें (विफल)',
    'biometric.btn_retry': 'पुनः अंगूठा स्कैन करें',
    'biometric.btn_authorize': 'अधिकृत करें एवं राशन वितरित करें',
    'biometric.btn_completed': 'पूर्ण / रसीद बंद करें',
    'biometric.summary_entitlement': 'मासिक कोटा: {max} किग्रा',
    'biometric.summary_distributed': 'वितरित: {dist} किग्रा',
    'biometric.summary_remaining': 'शेष: {rem} किग्रा',
    'biometric.btn_verify_fps': 'बायोमेट्रिक सत्यापित करें और राशन प्राप्त करें',
    'biometric.btn_verify_home': 'बायोमेट्रिक सत्यापित करें और डिलीवरी प्राप्त करें',
    'biometric.fps_banner': 'दुकान काउंटर पर राशन प्राप्त करने से पूर्व अंगूठा सत्यापन अनिवार्य है।',
    'biometric.doorstep_banner': 'डोरस्टेप वितरण एजेंट के आगमन पर अंगूठा सत्यापन अनिवार्य है।',
    'biometric.distributed_badge': 'बायोमेट्रिक द्वारा सत्यापित वितरण',

    // Pre-Dispatch Decision Pipeline & Live Timers
    'predispatch.modal_title': 'प्रेषण-पूर्व निर्णय विश्लेषण (Pre-Dispatch Analysis)',
    'predispatch.running': 'निर्णय पाइपलाइन निष्पादन जारी है...',
    'predispatch.completed_all': 'प्रेषण-पूर्व विश्लेषण निष्पादन पूर्ण',
    'predispatch.stage_forecast': '1. पूर्वानुमान (FORECAST)',
    'predispatch.stage_decision': '2. निर्णय (DECISION)',
    'predispatch.stage_validate': '3. सत्यापन (VALIDATE)',
    'predispatch.stage_optimize': '4. अनुकूलन (OPTIMIZE)',
    'predispatch.stage_manifest': '5. मैनिफेस्ट (MANIFEST)',
    'predispatch.stage_notify': '6. अधिसूचना (NOTIFICATION)',
    'predispatch.forecast_desc': 'नागरिक प्राथमिकताओं एवं बहु-कारक मांग का संकलन',
    'predispatch.validate_desc': '9 वैधानिक नियमों व बफर स्टॉक की सत्यता जांच',
    'predispatch.optimize_desc': 'मल्टी-स्टॉप रूटिंग व वाहन अनुकूलन गणना',
    'predispatch.manifest_desc': 'क्रिप्टोग्राफिक SHA-256 डिजिटल गेटपास सील',
    'predispatch.scenario_normal': 'परिदृश्य A: स्टॉक उपलब्ध (सामान्य प्रेषण)',
    'predispatch.scenario_shortage': 'परिदृश्य B: सरकारी स्टॉक की कमी (1-2 दिन का अस्थायी विलंब)',
    'predispatch.btn_run': 'प्रेषण-पूर्व विश्लेषण चलाएं',
    'predispatch.btn_proceed_dispatch': 'मैनिफेस्ट लॉक करें एवं प्रेषण जारी रखें',
    'predispatch.btn_delay_dispatch': 'प्रेषण विलंबित करें (1-2 दिन) एवं नागरिक को सूचित करें',
    'predispatch.btn_resume_dispatch': 'प्रेषण पुनः आरंभ करें (स्टॉक उपलब्ध)',
    'predispatch.stock_warning_title': '⚠️ सरकारी स्टॉक की कमी दर्ज',
    'predispatch.stock_warning_desc': 'वर्तमान प्रेषण के लिए सरकारी स्टॉक उपलब्ध नहीं है। अनुमानित विलंब 1-2 दिन है।',
    'predispatch.policy_notice': 'सरकारी नीति: स्टॉक की कमी एक अस्थायी विलंब है, रद्दीकरण नहीं। आपका ऑर्डर पूर्णतः सुरक्षित है।',

    // Temporary Stock Shortage Delay
    'delay.banner_title': '⏳ वितरण विलंबित (Delivery Delayed)',
    'delay.banner_desc': 'सरकारी स्टॉक उपलब्धता के कारण आपका राशन वितरण अस्थायी रूप से विलंबित है। यह 1-2 दिनों के भीतर पूरा होने की उम्मीद है।',
    'delay.badge': 'विलंबित — स्टॉक पुनःपूर्ति लंबित',
    'delay.reason_label': 'विलंब का कारण',
    'delay.reason_stock': 'सरकारी स्टॉक उपलब्धता',
    'delay.expected_label': 'अपेक्षित पूर्णता समय',
    'delay.expected_window': '1–2 दिनों के भीतर',
    'delay.no_resubmit_hint': 'आपको पुनः आवेदन करने की आवश्यकता नहीं है। आपका कोटा सुरक्षित है।',
    'delay.officer_notify_title': 'लाभार्थी को अस्थायी विलंब की सूचना भेजें',
    'delay.officer_msg_template': 'सरकारी स्टॉक उपलब्ध न होने के कारण आपका राशन वितरण अस्थायी रूप से विलंबित हो गया है। वितरण 1-2 दिनों में होने की संभावना है। आपको पुनः अनुरोध प्रस्तुत करने की आवश्यकता नहीं है।',
    'delay.btn_send_alert': 'विलंब अलर्ट भेजें (SMS / WhatsApp)',
    'delay.alert_sent_success': 'अस्थायी विलंब की सूचना लाभार्थी को SMS द्वारा सफलतापूर्वक भेजी गई।',

    // Navigation & Common
    'nav.logout': 'लॉगआउट',
    'nav.back': 'पीछे जाएं',
    'nav.close': 'बंद करें',
    'nav.cancel': 'रद्द करें',
    'nav.refresh': 'रिफ्रेश',
  },

  'kn': {
    // General & Brand
    'app.name': 'ಪಿಡಿಎಸ್ ಡಿಮ್ಯಾಂಡ್‌ಸಿಂಕ್ (PDS DemandSync)',
    'app.subtitle': 'ಸಾರ್ವಜನಿಕ ವಿತರಣಾ ವ್ಯವಸ್ಥೆಗೆ ರವಾನೆ ಪೂರ್ವ ಬೇಡಿಕೆ ಮುನ್ಸೂಚನೆ ಮತ್ತು ನಾಗರಿಕ ಸಮನ್ವಯ',
    'app.gov_badge': 'ಕರ್ನಾಟಕ ಸರ್ಕಾರ • ಬೆಂಗಳೂರು ನಗರ ಪಿಡಿಎಸ್ ಪ್ರಾಯೋಗಿಕ ಯೋಜನೆ',
    'app.dashboard': 'ನಾಗರಿಕ ಫಲಾನುಭವಿ ಪೋರ್ಟಲ್',
    'app.nfsa_notice': 'ರಾಷ್ಟ್ರೀಯ ಆಹಾರ ಭದ್ರತಾ ಕಾಯ್ದೆ • ಸಾರ್ವಜನಿಕ ವಿತರಣಾ ಪೋರ್ಟಲ್',
    'app.cycle_label': 'ಸೆಪ್ಟೆಂಬರ್ 2026 (ಸುತ್ತು 7)',

    // Language Selector
    'lang.selector_title': 'ಭಾಷೆ / Language / भाषा',
    'lang.english': 'English',
    'lang.hindi': 'हिंदी',
    'lang.kannada': 'ಕನ್ನಡ',

    // Login Screen
    'login.officer_portal_title': 'ಜಿಲ್ಲಾ ಸರಬರಾಜು ಕಾರ್ಯಾಚರಣೆ ಪೋರ್ಟಲ್',
    'login.officer_portal_subtitle': 'ಆಹಾರ ಮತ್ತು ನಾಗರಿಕ ಸರಬರಾಜು ಇಲಾಖೆ • ಬೆಂಗಳೂರು ನಗರ',
    'profile.fps_label': 'ನೋಂದಾಯಿತ ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿ (FPS)',
    'profile.family_members': 'ಕುಟುಂಬದ ಸದಸ್ಯರು',
    'profile.status_active': 'ಸಕ್ರಿಯ ಮತ್ತು ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
    'profile.card_type': 'ಚೀಟಿ ವಿಧ: {type}',
    'profile.loading': 'ಸರ್ಕಾರಿ ಪಡಿತರ ದಾಖಲೆಗಳನ್ನು ಲೋಡ್ ಮಾಡಲಾಗುತ್ತಿದೆ...',
    'profile.error_retry': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',

    // Commodities & Units
    'commodity.rice': 'ಅಕ್ಕಿ',
    'commodity.wheat': 'ಗೋಧಿ',
    'commodity.kg': 'ಕೆ.ಜಿ.',
    'commodity.free_tag': '100% ಉಚಿತ',
    'commodity.entitled_free': '100% ಉಚಿತ',

    // Statutory Entitlement Card
    'entitlement.title': 'ನಿಮ್ಮ ಪಡಿತರ ಪ್ರಮಾಣ',
    'entitlement.non_editable': 'ಬದಲಾಯಿಸಲಾಗದು',
    'entitlement.monthly_quota': 'ಮಾಸಿಕ ಕೋಟಾ',
    'entitlement.consumed': 'ಈ ಸುತ್ತಿನಲ್ಲಿ ಪಡೆದ ಪಡಿತರ',
    'entitlement.remaining_balance': 'ಲಭ್ಯವಿರುವ ಉಳಿದ ಬಾಕಿ',
    'entitlement.statutory_rule': 'ನಿಮ್ಮ ಪಡಿತರ ಅರ್ಹತೆಯನ್ನು ಸರ್ಕಾರಿ ನಿಯಮಾವಳಿಗಳ ಪ್ರಕಾರ ನಿಗದಿಪಡಿಸಲಾಗಿದೆ. ನೀವು ಪ್ರಮಾಣವನ್ನು ಹೆಚ್ಚಿಸಲು ಅಥವಾ ಬದಲಾಯಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ.',

    // Service Choice Section
    'service.plan_title': 'ನಿಮ್ಮ ಮುಂಬರುವ ಪಡಿತರ ಸಂಗ್ರಹ ಯೋಜಿಸಿ',
    'service.plan_subtitle': 'ಗೋಡೌನ್‌ನಿಂದ ಲಾರಿ ಹೊರಡುವ ಮುನ್ನವೇ ಆಹಾರ ಧಾನ್ಯ ಸಿದ್ಧಪಡಿಸಲು ನಿಮ್ಮ ಆದ್ಯತೆಯನ್ನು ಮುಂಚಿತವಾಗಿ ತಿಳಿಸಿ',
    'service.fps_choice_title': 'ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿಯಿಂದ ಪಡೆಯಿರಿ',
    'service.fps_choice_desc': 'ನಿಮ್ಮ ನೋಂದಾಯಿತ ಅಂಗಡಿ ಅಥವಾ ಯಾವುದೇ ಹತ್ತಿರದ ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿಯಿಂದ ನೇರವಾಗಿ ಪಡಿತರ ಸಂಗ್ರಹಿಸಿ.',
    'service.fps_choice_detail': 'ನಿಗದಿತ ಕೇಂದ್ರ: {fpsName}',
    'service.fps_choice_badge': 'ಉಚಿತ ಸಂಗ್ರಹ',
    'service.fps_choice_price': 'ಸಂಪೂರ್ಣ ಉಚಿತ (₹0.00)',
    'service.fps_choice_btn': 'ಅಂಗಡಿ ಆಯ್ಕೆಮಾಡಿ',
    'service.home_choice_title': 'ಮನೆಬಾಗಿಲಿಗೆ ಪಡಿತರ ವಿತರಣೆ',
    'service.home_choice_desc': 'ಅಧಿಕೃತ ವಿತರಣಾ ಪಾಲುದಾರರು ಮೊಹರು ಮಾಡಿದ ಪಡಿತರವನ್ನು ನೇರವಾಗಿ ನಿಮ್ಮ ಮನೆಗೆ ತಲುಪಿಸುತ್ತಾರೆ.',
    'service.home_choice_detail': 'ವಿತರಣಾ ವಿಳಾಸ: ಬೆಂಗಳೂರು ನಗರ',
    'service.home_choice_badge': 'ಮನೆಬಾಗಿಲು ಸೇವೆ',
    'service.home_choice_price': 'ಸಾಗಾಣಿಕೆ ಶುಲ್ಕ: ₹87.50',
    'service.home_choice_btn': 'ವಿತರಣೆ ಆಯ್ಕೆಮಾಡಿ',

    // Order & Delivery Tracking
    'delivery.section_title': 'ಪ್ರಸ್ತುತ ಕೋರಿಕೆ ಮತ್ತು ಪಡಿತರ ವಿತರಣಾ ಸ್ಥಿತಿ',
    'delivery.order_num': 'ಆರ್ಡರ್ #{orderId}',
    'delivery.timeline_requested': 'ವಿನಂತಿಸಲಾಗಿದೆ',
    'delivery.timeline_allocated': 'ಹಂಚಿಕೆ ಮಾಡಲಾಗಿದೆ',
    'delivery.timeline_out_for_delivery': 'ವಿತರಣೆಗೆ ಹೊರಟಿದೆ',
    'delivery.timeline_delivered': 'ವಿತರಿಸಲಾಗಿದೆ',
    'delivery.timeline_confirmed': 'ದೃಢೀಕರಿಸಲಾಗಿದೆ',
    'delivery.authorized_commodities': 'ಅಧಿಕೃತ ಪಡಿತರ ಆಹಾರ ಧಾನ್ಯಗಳು',
    'delivery.mode_home': 'ಮನೆಬಾಗಿಲಿಗೆ ವಿತರಣೆ (ಹೋಮ್ ಡೆಲಿವರಿ)',
    'delivery.mode_fps': 'ಅಂಗಡಿಯಿಂದ ಸಂಗ್ರಹ (ಎಫ್‌ಪಿಎಸ್)',
    'delivery.logistics_fee': 'ಸಾಗಾಣಿಕೆ ಶುಲ್ಕ: ₹{fee}',
    'delivery.pickup_location': 'ಸಂಗ್ರಹ ಕೇಂದ್ರ: {fpsName}',
    'delivery.delivery_address': 'ವಿಳಾಸ: {address}',
    'delivery.did_you_receive': 'ನಿಮ್ಮ ಪಡಿತರ ನಿಮಗೆ ತಲುಪಿದೆಯೇ?',
    'delivery.btn_confirm_full': 'ಹೌದು, ನನಗೆ ಪೂರ್ಣ ಪ್ರಮಾಣ ದೊರೆತಿದೆ',
    'delivery.btn_report_issue': 'ಪ್ರಮಾಣದ ಸಮಸ್ಯೆಯನ್ನು ವರದಿ ಮಾಡಿ',
    'delivery.confirm_success': 'ವಿತರಣೆ ದೃಢೀಕರಿಸಲಾಗಿದೆ! ಸಂಪೂರ್ಣ ಕೋಟಾ ರಸೀದಿಯನ್ನು ಜಿಲ್ಲಾ ಸರಬರಾಜು ಕಚೇರಿಯಲ್ಲಿ ನೋಂದಾಯಿಸಲಾಗಿದೆ.',
    'delivery.dispute_reason_banner': 'ದೂರಿನ ಕಾರಣ: {reason} (ಅಧಿಕಾರಿಗಳ ತನಿಖೆಯಲ್ಲಿದೆ)',

    // Delivery Dispute Modal
    'dispute.modal_title': 'ಪಡಿತರ ವಿತರಣಾ ವ್ಯತ್ಯಾಸವನ್ನು ವರದಿ ಮಾಡಿ',
    'dispute.order_ref': 'ಆರ್ಡರ್ #{orderId} • ಅಧಿಕೃತ ಕೋಟಾ: {quota}',
    'dispute.detected_shortfall': 'ಕಂಡುಬಂದ ಕೊರತೆ:',
    'dispute.rice_shortfall': '• ಅಕ್ಕಿ ಕೊರತೆ: {qty} ಕೆ.ಜಿ. ಕಡಿಮೆಯಾಗಿದೆ',
    'dispute.wheat_shortfall': '• ಗೋಧಿ ಕೊರತೆ: {qty} ಕೆ.ಜಿ. ಕಡಿಮೆಯಾಗಿದೆ',
    'dispute.actual_rice_label': 'ವಾಸ್ತವವಾಗಿ ಪಡೆದ ಅಕ್ಕಿ (ಕೆ.ಜಿ.) • ಅಧಿಕೃತ: {expected} ಕೆ.ಜಿ.',
    'dispute.actual_wheat_label': 'ವಾಸ್ತವವಾಗಿ ಪಡೆದ ಗೋಧಿ (ಕೆ.ಜಿ.) • ಅಧಿಕೃತ: {expected} ಕೆ.ಜಿ.',
    'dispute.remarks_label': 'ವ್ಯತ್ಯಾಸದ ವಿವರಗಳು / ಟಿಪ್ಪಣಿ',
    'dispute.remarks_hint': 'ಉದಾ: ತೂಕದಲ್ಲಿ ವ್ಯತ್ಯಾಸ, ಹಾನಿಗೊಳಗಾದ ಚೀಲ, ಕಾಣೆಯಾದ ವಸ್ತುಗಳು',
    'dispute.btn_submit': 'ಜಿಲ್ಲಾ ಸರಬರಾಜು ಅಧಿಕಾರಿಗೆ ದೂರು ಸಲ್ಲಿಸಿ',
    'dispute.submitting': 'ದೂರು ದಾಖಲಾಗುತ್ತಿದೆ...',
    'dispute.success': 'ದೂರು ದಾಖಲಿಸಲಾಗಿದೆ. ವಿಚಾರಣೆಗಾಗಿ ಜಿಲ್ಲಾ ಸರಬರಾಜು ಅಧಿಕಾರಿಗೆ (DSO) ಕಳುಹಿಸಲಾಗಿದೆ.',

    // History Section
    'history.title': 'ಘೋಷಿತ ಆದ್ಯತಾ ಸಂಕೇತಗಳ ಇತಿಹಾಸ',
    'history.view_timeline': 'ಸಂಪೂರ್ಣ ಕಾಲಾವಧಿ ವೀಕ್ಷಿಸಿ →',
    'history.empty': 'ಮುಂಬರುವ ಸುತ್ತುಗಳಿಗಾಗಿ ನೀವು ಇನ್ನೂ ಯಾವುದೇ ಮುಂಗಡ ಆದ್ಯತಾ ಘೋಷಣೆಗಳನ್ನು ಸಲ್ಲಿಸಿಲ್ಲ.',
    'history.screen_title': 'ಘೋಷಿತ ಆದ್ಯತಾ ಸಂಕೇತಗಳ ಇತಿಹಾಸ',
    'history.screen_subtitle': 'ಪಿಡಿಎಸ್ ಡಿಮ್ಯಾಂಡ್‌ಸಿಂಕ್ • ಮುಂಗಡ ಪೂರೈಕೆ ಯೋಜನಾ ದಾಖಲೆಗಳು',
    'history.timeline_header': 'ಕಾಲಾನುಕ್ರಮದ ಆದ್ಯತಾ ಸಂಕೇತಗಳು',
    'history.intended_fps_label': 'ಉದ್ದೇಶಿತ ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿ',
    'history.no_signals': 'ಯಾವುದೇ ಹಿಂದಿನ ಸಂಕೇತಗಳು ಕಂಡುಬಂದಿಲ್ಲ',

    // Intent Selection Screen
    'intent.screen_title': 'ಪಡಿತರ ಸಂಗ್ರಹ ಆದ್ಯತೆಯನ್ನು ತಿಳಿಸಿ',
    'intent.step_service': 'ಸೇವೆಯ ವಿಧಾನ',
    'intent.step_fps': 'ಸ್ಥಳ / ಅಂಗಡಿ',
    'intent.step_review': 'ಪರಿಶೀಲನೆ',
    'intent.step_confirm': 'ದೃಢೀಕರಣ',
    'intent.section1_title': 'ನಿಮ್ಮ ಪಡಿತರವನ್ನು ನೀವು ಹೇಗೆ ಪಡೆಯಲು ಬಯಸುತ್ತೀರಿ?',
    'intent.fps_choice_title': 'ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿಯಿಂದ ಪಡೆಯಿರಿ',
    'intent.home_choice_title': 'ಮನೆಬಾಗಿಲಿಗೆ ಪಡಿತರ ವಿತರಣೆ',
    'intent.section2_title': 'ನಿಮ್ಮ ಉದ್ದೇಶಿತ ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿ ಆಯ್ಕೆಮಾಡಿ',
    'intent.fps_search_hint': 'ಅಂಗಡಿ ಹೆಸರು ಅಥವಾ ಎಫ್‌ಪಿಎಸ್ ಕೋಡ್ ಹುಡುಕಿ...',
    'intent.home_fps_tag': 'ಮೂಲ ಅಂಗಡಿ',
    'intent.portability_tag': 'ಪೋರ್ಟೆಬಿಲಿಟಿ ಶಿಫ್ಟ್',
    'intent.section3_title': 'ಮನೆ ವಿಳಾಸ ಮತ್ತು ಸಾಗಾಣಿಕೆ ವೆಚ್ಚ',
    'intent.address_label': 'ಬೆಂಗಳೂರು ನಗರದಲ್ಲಿನ ವಿತರಣಾ ವಿಳಾಸ',
    'intent.distance_label': 'ಹತ್ತಿರದ ಕೇಂದ್ರದಿಂದ ದೂರ: {dist} ಕಿ.ಮೀ.',
    'intent.logistics_breakdown': 'ಸಾಗಾಣಿಕೆ ಶುಲ್ಕ: ಮೂಲ ₹20.00 + ದೂರದ ಶುಲ್ಕ = ₹{fee}',
    'intent.section4_title': 'ನಿಮ್ಮ ಕಾನೂನುಬದ್ಧ ಪಡಿತರ ಸಾರಾಂಶ',
    'intent.btn_continue': 'ಪರಿಶೀಲನೆ ಮತ್ತು ದೃಢೀಕರಣಕ್ಕೆ ಮುಂದುವರಿಯಿರಿ',
    'intent.btn_continue_fps': 'ಅಂಗಡಿ ಸಂಗ್ರಹ ಪರಿಶೀಲನೆಗೆ ಮುಂದುವರಿಯಿರಿ (₹0.00 ಉಚಿತ)',
    'intent.btn_continue_home': 'ಮನೆಬಾಗಿಲು ವಿತರಣೆ ಪರಿಶೀಲನೆಗೆ ಮುಂದುವರಿಯಿರಿ (₹{fee})',
    'intent.policy_footer': 'ಆಹಾರ ಧಾನ್ಯಗಳು 100% ಉಚಿತ (₹0.00/ಕೆ.ಜಿ.) • ಮುಂಚಿತ ಆದ್ಯತೆಯು ಕೊರತೆಯನ್ನು ತಡೆಯುತ್ತದೆ',

    // Intent Confirmation Screen
    'confirm.review_title': 'ನಿಮ್ಮ ಸಂಗ್ರಹ ಯೋಜನೆಯನ್ನು ಪರಿಶೀಲಿಸಿ',
    'confirm.review_subtitle': 'ಜಿಲ್ಲಾ ರವಾನೆ ಇಂಜಿನ್‌ಗೆ ಸಲ್ಲಿಸುವ ಮೊದಲು ದಯವಿಟ್ಟು ನಿಮ್ಮ ಆದ್ಯತೆಗಳನ್ನು ಪರಿಶೀಲಿಸಿ.',
    'confirm.success_heading': 'ಸಂಗ್ರಹ ಯೋಜನೆ ಸಲ್ಲಿಸಲಾಗಿದೆ',
    'confirm.success_desc': 'ನಿಮ್ಮ ಪಡಿತರ ಸಂಗ್ರಹ ಆದ್ಯತೆಯನ್ನು ಪಿಡಿಎಸ್ ರವಾನೆ-ಪೂರ್ವ ಬೇಡಿಕೆ ಇಂಜಿನ್‌ನಲ್ಲಿ ಯಶಸ್ವಿಯಾಗಿ ದಾಖಲಿಸಲಾಗಿದೆ.',
    'confirm.gov_notice_title': 'ಪ್ರಮುಖ ಸರ್ಕಾರಿ ಸೂಚನೆ',
    'confirm.gov_notice_desc': 'ನಿಮ್ಮ ಪಡಿತರ ಅರ್ಹತೆಯನ್ನು ಸರ್ಕಾರಿ ನಿಯಮಾವಳಿಗಳ ಪ್ರಕಾರ ನಿಗದಿಪಡಿಸಲಾಗಿದೆ. ಈ ವಿನಂತಿಯು ನಿಮ್ಮ ಕಾನೂನುಬದ್ಧ ಪಡಿತರ ಪ್ರಮಾಣವನ್ನು ಹೆಚ್ಚಿಸುವುದಿಲ್ಲ ಅಥವಾ ಬದಲಾಯಿಸುವುದಿಲ್ಲ.',
    'confirm.gov_transport_note': 'ಕೇವಲ ಸಾಗಾಣಿಕೆ/ಲಾಜಿಸ್ಟಿಕ್ಸ್ ಶುಲ್ಕ ಮಾತ್ರ ಅನ್ವಯಿಸುತ್ತದೆ.',
    'confirm.what_next_title': 'ಮುಂದೇನು ನಡೆಯುತ್ತದೆ',
    'confirm.you_pay': 'ಒಟ್ಟು ಪಾವತಿಸಬೇಕಾದ ಮೊತ್ತ / ನೀವು ಪಾವತಿಸುವುದು',
    'confirm.step1_title': 'ವಿನಂತಿ ದಾಖಲಾಗಿದೆ',
    'confirm.step1_desc': 'ನಿಮ್ಮ ಆಯ್ಕೆಯ ವಿಧಾನವನ್ನು ಜಿಲ್ಲಾ ಮುಂಗಡ ಬೇಡಿಕೆ ವ್ಯವಸ್ಥೆಯಲ್ಲಿ ದಾಖಲಿಸಲಾಗಿದೆ.',
    'confirm.step2_title': 'ಸರ್ಕಾರಿ ಹಂಚಿಕೆ ಪರಿಶೀಲನೆ',
    'confirm.step2_desc': 'ಜಿಲ್ಲಾ ಸರಬರಾಜು ಕಚೇರಿಯು ದಾಸ್ತಾನು ಪರಿಶೀಲಿಸಿ ವಾಹನ ರವಾನೆಯನ್ನು ನಿಗದಿಪಡಿಸುತ್ತದೆ.',
    'confirm.step3_title': 'ಹಂಚಿಕೆ ದೃಢೀಕರಣ',
    'confirm.step3_desc': 'ನಿಗದಿತ ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿಗೆ ಮುಂಗಡ ಧಾನ್ಯ ಸಂಗ್ರಹ ಹಂಚಿಕೆ ದೊರೆಯುತ್ತದೆ.',
    'confirm.step4_title': 'ವಿತರಣೆ / ಸಂಗ್ರಹ',
    'confirm.step4_desc': 'ಪಡಿತರ ನಿಮ್ಮ ಮನೆಬಾಗಿಲಿಗೆ ತಲುಪುತ್ತದೆ ಅಥವಾ ಅಂಗಡಿಯಿಂದ ಸಂಗ್ರಹಿಸಲು ಸಿದ್ಧವಾಗಿರುತ್ತದೆ.',
    'confirm.step5_title': 'ನಾಗರಿಕ ರಸೀದಿ ದೃಢೀಕರಣ',
    'confirm.step5_desc': 'ನೀವು ಧಾನ್ಯದ ಪ್ರಮಾಣವನ್ನು ಪರಿಶೀಲಿಸಿ ಡಿಜಿಟಲ್ ಪೋರ್ಟಲ್‌ನಲ್ಲಿ ದೃಢೀಕರಿಸುತ್ತೀರಿ.',
    'confirm.btn_submit_plan': 'ಸಂಗ್ರಹ ಯೋಜನೆ ಸಲ್ಲಿಸಿ',
    'confirm.btn_submitting': 'ಯೋಜನೆ ಸಲ್ಲಿಸಲಾಗುತ್ತಿದೆ...',
    'confirm.btn_go_back': 'ಹಿಂದಕ್ಕೆ ಹೋಗಿ ಆಯ್ಕೆಗಳನ್ನು ಬದಲಾಯಿಸಿ',
    'confirm.receipt_title': 'ಡಿಜಿಟಲ್ ಆದ್ಯತಾ ರಸೀದಿ',
    'confirm.receipt_next_step': 'ಮುಂದಿನ ಹಂತ',
    'confirm.receipt_next_step_desc': 'ಜಿಲ್ಲಾ ಸರಬರಾಜು ಕಚೇರಿಯು ಬೇಡಿಕೆ ಸಂಕೇತಗಳನ್ನು ಸಂಗ್ರಹಿಸುತ್ತಿದೆ. ಧಾನ್ಯ ಸಿದ್ಧವಾದಾಗ ನಿಮಗೆ ಎಸ್‌ಎಂಎಸ್ ದೊರೆಯುತ್ತದೆ.',
    'confirm.btn_view_portal': 'ನಾಗರಿಕ ಪೋರ್ಟಲ್‌ನಲ್ಲಿ ಸ್ಥಿತಿ ವೀಕ್ಷಿಸಿ',
    'confirm.btn_view_history': 'ಎಲ್ಲಾ ದಾಖಲಾದ ಸಂಕೇತಗಳನ್ನು ವೀಕ್ಷಿಸಿ',

    // Household Members & Calculation
    'members.title': 'ಅರ್ಹ ಕುಟುಂಬ ಸದಸ್ಯರು',
    'members.badge': '5.0 ಕೆ.ಜಿ. / ಅರ್ಹ ವ್ಯಕ್ತಿಗೆ',
    'members.subtitle': 'ಕಾನೂನುಬದ್ಧ ಪಡಿತರ ಅರ್ಹತೆಯ ಅಡಿಯಲ್ಲಿ ಆಹಾರ ಧಾನ್ಯಗಳಿಗೆ ಅರ್ಹರಾಗಿರುವ ಕುಟುಂಬ ಸದಸ್ಯರ ಸಂಖ್ಯೆ',
    'members.formula': '{count} ಸದಸ್ಯರು × 5.0 ಕೆ.ಜಿ. = {max} ಕೆ.ಜಿ. ಗರಿಷ್ಠ ಕುಟುಂಬ ಕೋಟಾ',
    'members.allocation_title': 'ಸಂಯೋಜಿತ ಆಹಾರ ಧಾನ್ಯ ಹಂಚಿಕೆ',
    'members.rice_alloc': 'ಅಕ್ಕಿ ಹಂಚಿಕೆ',
    'members.wheat_alloc': 'ಗೋಧಿ ಹಂಚಿಕೆ',
    'members.over_error': 'ಒಟ್ಟು ವಿನಂತಿಸಿದ ಪ್ರಮಾಣ ({qty} ಕೆ.ಜಿ.) {count} ಅರ್ಹ ಸದಸ್ಯರಿಗೆ ಗರಿಷ್ಠ ಕುಟುಂಬ ಅರ್ಹತೆಗಿಂತ ({max} ಕೆ.ಜಿ.) ಹೆಚ್ಚಾಗಿದೆ.',
    'members.adjust_hint': 'ನಿಮ್ಮ ಕಾನೂನುಬದ್ಧ ಕೋಟಾದ ಮಿತಿಯಲ್ಲಿರಲು ಪ್ರಮಾಣವನ್ನು ಸರಿಹೊಂದಿಸಿ.',

    // Biometric & Delivery Verification
    'biometric.title_fps': 'ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿ ಬಯೋಮೆಟ್ರಿಕ್ ಪರಿಶೀಲನೆ',
    'biometric.title_home': 'ಮನೆಬಾಗಿಲ ಬಯೋಮೆಟ್ರಿಕ್ ಪರಿಶೀಲನೆ',
    'biometric.check_heading': '3-ಹಂತದ ಅರ್ಹತಾ ಪರಿಶೀಲನೆ:',
    'biometric.check1': 'ಫಲಾನುಭವಿಯ ಆಧಾರ್ ಗುರುತು ಹೊಂದಾಣಿಕೆ (ePoS ಸ್ಕ್ಯಾನರ್)',
    'biometric.check2': 'ಪಡಿತರ ಚೀಟಿ ಸಕ್ರಿಯ ಮತ್ತು ಅಮಾನತುಗೊಂಡಿಲ್ಲ',
    'biometric.check3': 'ಲಭ್ಯವಿರುವ ಪಡಿತರ ಕೋಟಾ ({qty} ಕೆ.ಜಿ. ಅರ್ಹತೆ)',
    'biometric.status_initial': 'ಹೆಬ್ಬೆರಳು ಪರಿಶೀಲನೆಗೆ ಸಿದ್ಧ',
    'biometric.status_scanning': 'ePoS / ಆಧಾರ್ ಸರ್ವರ್ ಸಂಪರ್ಕಿಸಲಾಗುತ್ತಿದೆ...',
    'biometric.status_verified': 'ಪರಿಶೀಲನೆ ಯಶಸ್ವಿ • ಅಧಿಕೃತಗೊಳಿಸಲಾಗಿದೆ',
    'biometric.status_failed': 'ಬಯೋಮೆಟ್ರಿಕ್ ವಿಫಲ • ವಿತರಣೆ ಸ್ಥಗಿತಗೊಂಡಿದೆ',
    'biometric.status_distributed': 'ಆಹಾರ ಧಾನ್ಯ ವಿತರಿಸಲಾಗಿದೆ ಮತ್ತು ದಾಖಲಿಸಲಾಗಿದೆ',
    'biometric.desc_initial': 'ವಿತರಣೆಯನ್ನು ದೃಢೀಕರಿಸಲು ಫಲಾನುಭವಿಯ ಹೆಬ್ಬೆರಳನ್ನು ಸ್ಕ್ಯಾನರ್ ಮೇಲೆ ಇರಿಸಿ.',
    'biometric.desc_scanning': 'ಬಯೋಮೆಟ್ರಿಕ್ ಮುದ್ರೆಯನ್ನು ಡೇಟಾಬೇಸ್‌ನೊಂದಿಗೆ ಹೊಂದಿಸಲಾಗುತ್ತಿದೆ...',
    'biometric.desc_verified': 'ಗುರುತು, ಪಡಿತರ ಚೀಟಿ ಸ್ಥಿತಿ ಮತ್ತು ಕೋಟಾ ಪರಿಶೀಲಿಸಲಾಗಿದೆ. ಧಾನ್ಯ ನೀಡಲು ಸಿದ್ಧ.',
    'biometric.desc_failed': 'ಹೆಬ್ಬೆರಳಿನ ಗುರುತು ನೋಂದಾಯಿತ ದಾಖಲೆಗೆ ಹೊಂದಾಣಿಕೆಯಾಗುತ್ತಿಲ್ಲ.',
    'biometric.desc_distributed': 'ವಿತರಣೆ ಪೂರ್ಣಗೊಂಡಿದೆ. ಕೇಂದ್ರೀಯ ಪಿಡಿಎಸ್ ಲೆಡ್ಜರ್‌ನಲ್ಲಿ ಕೋಟಾ ನವೀಕರಿಸಲಾಗಿದೆ.',
    'biometric.btn_simulate_match': 'ಹೆಬ್ಬೆರಳು ಹೊಂದಾಣಿಕೆ ಸಿಮ್ಯುಲೇಶನ್ (ಯಶಸ್ಸು)',
    'biometric.btn_simulate_mismatch': 'ಹೊಂದಾಣಿಕೆಯಾಗದ ಸಿಮ್ಯುಲೇಶನ್ (ವಿಫಲ)',
    'biometric.btn_retry': 'ಮತ್ತೊಮ್ಮೆ ಹೆಬ್ಬೆರಳು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ',
    'biometric.btn_authorize': 'ಅಧಿಕೃತಗೊಳಿಸಿ ಮತ್ತು ಧಾನ್ಯ ವಿತರಿಸಿ',
    'biometric.btn_completed': 'ಪೂರ್ಣಗೊಂಡಿದೆ / ರಶೀದಿ ಮುಚ್ಚಿ',
    'biometric.summary_entitlement': 'ಮಾಸಿಕ ಕೋಟಾ: {max} ಕೆ.ಜಿ.',
    'biometric.summary_distributed': 'ವಿತರಿಸಲಾಗಿದೆ: {dist} ಕೆ.ಜಿ.',
    'biometric.summary_remaining': 'ಉಳಿದಿರುವುದು: {rem} ಕೆ.ಜಿ.',
    'biometric.btn_verify_fps': 'ಬಯೋಮೆಟ್ರಿಕ್ ಪರಿಶೀಲಿಸಿ ಧಾನ್ಯ ಪಡೆಯಿರಿ',
    'biometric.btn_verify_home': 'ಬಯೋಮೆಟ್ರಿಕ್ ಪರಿಶೀಲಿಸಿ ವಿತರಣೆ ಪಡೆಯಿರಿ',
    'biometric.fps_banner': 'ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿಯಲ್ಲಿ ಪಡಿತರ ಪಡೆಯುವ ಮೊದಲು ಹೆಬ್ಬೆರಳು ಪರಿಶೀಲನೆ ಕಡ್ಡಾಯವಾಗಿದೆ.',
    'biometric.doorstep_banner': 'ಮನೆಬಾಗಿಲಿಗೆ ತಲುಪಿಸಿದಾಗ ಧಾನ್ಯ ವಿತರಣೆಯ ಮೊದಲು ಹೆಬ್ಬೆರಳು ಪರಿಶೀಲನೆ ಕಡ್ಡಾಯವಾಗಿದೆ.',
    'biometric.distributed_badge': 'ಬಯೋಮೆಟ್ರಿಕ್ ದೃಢೀಕರಣದೊಂದಿಗೆ ವಿತರಿಸಲಾಗಿದೆ',

    // Pre-Dispatch Decision Pipeline & Live Timers
    'predispatch.modal_title': 'ರವಾನೆ ಪೂರ್ವ ನಿರ್ಧಾರ ವಿಶ್ಲೇಷಣೆ (Pre-Dispatch Analysis)',
    'predispatch.running': 'ನಿರ್ಧಾರ ಪ್ರಕ್ರಿಯೆ ಚಾಲನೆಯಲ್ಲಿದೆ...',
    'predispatch.completed_all': 'ರವಾನೆ ಪೂರ್ವ ವಿಶ್ಲೇಷಣೆ ಯಶಸ್ವಿಯಾಗಿ ಪೂರ್ಣಗೊಂಡಿದೆ',
    'predispatch.stage_forecast': '1. ಮುನ್ಸೂಚನೆ (FORECAST)',
    'predispatch.stage_decision': '2. ನಿರ್ಧಾರ (DECISION)',
    'predispatch.stage_validate': '3. ಪರಿಶೀಲನೆ (VALIDATE)',
    'predispatch.stage_optimize': '4. ಆಪ್ಟಿಮೈಸೇಶನ್ (OPTIMIZE)',
    'predispatch.stage_manifest': '5. ಮ್ಯಾನಿಫೆಸ್ಟ್ (MANIFEST)',
    'predispatch.stage_notify': '6. ಅಧಿಸೂಚನೆ (NOTIFICATION)',
    'predispatch.forecast_desc': 'ನಾಗರಿಕ ಬೇಡಿಕೆ ಮತ್ತು ಮುನ್ಸೂಚನೆ ಕ್ರೋಢೀಕರಣ',
    'predispatch.validate_desc': '9 ಶಾಸನಬದ್ಧ ನಿಯಮಗಳು ಮತ್ತು ಬಫರ್ ದಾಸ್ತಾನು ಲೆಕ್ಕಪರಿಶೋಧನೆ',
    'predispatch.optimize_desc': 'ಮಲ್ಟಿ-ಸ್ಟಾಪ್ ವಾಹನ ಮಾರ್ಗ ಮತ್ತು ವಿತರಣಾ ವೇಳಾಪಟ್ಟಿ',
    'predispatch.manifest_desc': 'ಕ್ರಿಪ್ಟೋಗ್ರಾಫಿಕ್ SHA-256 ಡಿಜಿಟಲ್ ಗೇಟ್‌ಪಾಸ್ ಮೊಹರು',
    'predispatch.scenario_normal': 'ಸನ್ನಿವೇಶ A: ದಾಸ್ತಾನು ಲಭ್ಯವಿದೆ (ಸಾಮಾನ್ಯ ರವಾನೆ)',
    'predispatch.scenario_shortage': 'ಸನ್ನಿವೇಶ B: ಸರ್ಕಾರಿ ದಾಸ್ತಾನು ಕೊರತೆ (1-2 ದಿನಗಳ ತಾತ್ಕಾಲಿಕ ವಿಳಂಬ)',
    'predispatch.btn_run': 'ರವಾನೆ ಪೂರ್ವ ವಿಶ್ಲೇಷಣೆ ನಡೆಸಿ',
    'predispatch.btn_proceed_dispatch': 'ಮ್ಯಾನಿಫೆಸ್ಟ್ ಲಾಕ್ ಮಾಡಿ ರವಾನೆಗೆ ಮುಂದುವರಿಯಿರಿ',
    'predispatch.btn_delay_dispatch': 'ರವಾನೆ ವಿಳಂಬಿಸಿ (1-2 ದಿನಗಳು) ಮತ್ತು ನಾಗರಿಕರಿಗೆ ತಿಳಿಸಿ',
    'predispatch.btn_resume_dispatch': 'ರವಾನೆ ಮುಂದುವರಿಸಿ (ದಾಸ್ತಾನು ಲಭ್ಯ)',
    'predispatch.stock_warning_title': '⚠️ ಸರ್ಕಾರಿ ದಾಸ್ತಾನು ಕೊರತೆ ಕಂಡುಬಂದಿದೆ',
    'predispatch.stock_warning_desc': 'ಈ ರವಾನೆಗೆ ಸರ್ಕಾರಿ ದಾಸ್ತಾನು ತಾತ್ಕಾಲಿಕವಾಗಿ ಲಭ್ಯವಿಲ್ಲ. ನಿರೀಕ್ಷಿತ ವಿಳಂಬ 1-2 ದಿನಗಳು.',
    'predispatch.policy_notice': 'ಸರ್ಕಾರಿ ನೀತಿ: ದಾಸ್ತಾನು ಕೊರತೆಯು ತಾತ್ಕಾಲಿಕ ವಿಳಂಬವೇ ಹೊರತು ರದ್ದತಿಯಲ್ಲ. ನಿಮ್ಮ ಆರ್ಡರ್ ಸಂಪೂರ್ಣ ಸುರಕ್ಷಿತವಾಗಿದೆ.',

    // Temporary Stock Shortage Delay
    'delay.banner_title': '⏳ ವಿತರಣೆ ವಿಳಂಬವಾಗಿದೆ (Delivery Delayed)',
    'delay.banner_desc': 'ಸರ್ಕಾರಿ ದಾಸ್ತಾನು ಲಭ್ಯತೆಯ ಕಾರಣ ನಿಮ್ಮ ಪಡಿತರ ವಿತರಣೆ ತಾತ್ಕಾಲಿಕವಾಗಿ ವಿಳಂಬವಾಗಿದೆ. 1-2 ದಿನಗಳ ಒಳಗೆ ಪೂರ್ಣಗೊಳ್ಳುವ ನಿರೀಕ್ಷೆಯಿದೆ.',
    'delay.badge': 'ವಿಳಂಬವಾಗಿದೆ — ದಾಸ್ತಾನು ಪೂರೈಕೆ ಬಾಕಿ',
    'delay.reason_label': 'ವಿಳಂಬಕ್ಕೆ ಕಾರಣ',
    'delay.reason_stock': 'ಸರ್ಕಾರಿ ದಾಸ್ತಾನು ಲಭ್ಯತೆ ಕೊರತೆ',
    'delay.expected_label': 'ನಿರೀಕ್ಷಿತ ವಿತರಣಾ ಸಮಯ',
    'delay.expected_window': '1–2 ದಿನಗಳ ಒಳಗೆ',
    'delay.no_resubmit_hint': 'ನೀವು ಮತ್ತೆ ಅರ್ಜಿ ಸಲ್ಲಿಸುವ ಅಗತ್ಯವಿಲ್ಲ. ನಿಮ್ಮ ಪಡಿತರ ಕೋಟಾ ಸುರಕ್ಷಿತವಾಗಿದೆ.',
    'delay.officer_notify_title': 'ಫಲಾನುಭವಿಗೆ ತಾತ್ಕಾಲಿಕ ವಿಳಂಬದ ಸಂದೇಶ ಕಳುಹಿಸಿ',
    'delay.officer_msg_template': 'ಸರ್ಕಾರಿ ದಾಸ್ತಾನು ತಾತ್ಕಾಲಿಕವಾಗಿ ಲಭ್ಯವಿಲ್ಲದ ಕಾರಣ ನಿಮ್ಮ ಪಡಿತರ ವಿತರಣೆ ವಿಳಂಬವಾಗಿದೆ. 1-2 ದಿನಗಳಲ್ಲಿ ವಿತರಣೆ ಪೂರ್ಣಗೊಳ್ಳಲಿದೆ. ನೀವು ಮತ್ತೆ ಅರ್ಜಿ ಸಲ್ಲಿಸುವ ಅಗತ್ಯವಿಲ್ಲ.',
    'delay.btn_send_alert': 'ವಿಳಂಬ ಸಂದೇಶ ಕಳುಹಿಸಿ (SMS / WhatsApp)',
    'delay.alert_sent_success': 'ತಾತ್ಕಾಲಿಕ ವಿಳಂಬದ ಅಧಿಕೃತ ಸಂದೇಶವನ್ನು ಫಲಾನುಭವಿಗೆ SMS ಮೂಲಕ ಯಶಸ್ವಿಯಾಗಿ ಕಳುಹಿಸಲಾಗಿದೆ.',

    // Navigation & Common
    'nav.logout': 'ಲಾಗ್‌ಔಟ್',
    'nav.back': 'ಹಿಂದಕ್ಕೆ',
    'nav.close': 'ಮುಚ್ಚಿ',
    'nav.cancel': 'ರದ್ದುಮಾಡಿ',
    'nav.refresh': 'ರಿಫ್ರೆಶ್',
  },
};

// UI Component: Clean, responsive Language Selector Segmented Widget
class LanguageSelectorWidget extends StatelessWidget {
  final bool isCompact;
  final Color? backgroundColor;

  const LanguageSelectorWidget({
    super.key,
    this.isCompact = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        final current = LanguageController.instance.currentLanguage;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: backgroundColor != null
                  ? AppConstants.cardBorder
                  : Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.translate_rounded,
                  size: isCompact ? 13 : 15,
                  color: backgroundColor != null
                      ? AppConstants.primaryNavy
                      : Colors.white,
                ),
              ),
              ...AppLanguage.values.map((lang) {
                final isSelected = lang == current;
                return InkWell(
                  onTap: () => LanguageController.instance.setLanguage(lang),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 11,
                      vertical: isCompact ? 3 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (backgroundColor != null
                              ? AppConstants.primaryNavy
                              : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      lang.nativeName,
                      style: TextStyle(
                        fontSize: isCompact ? 11 : 12,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? (backgroundColor != null
                                ? Colors.white
                                : AppConstants.primaryNavy)
                            : (backgroundColor != null
                                ? AppConstants.textSecondary
                                : Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
