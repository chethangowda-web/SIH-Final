import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/delivery_timeline.dart';
import '../../services/voice_assistant_service.dart';
import '../../widgets/simple_beneficiary_feedback_dialog.dart';
import 'intent_selection_screen.dart';
import 'intent_history_screen.dart';
import 'demo_login_screen.dart';
import 'grain_atm/grain_atm_welcome_screen.dart';
import '../../services/beneficiary_voice_router.dart';

class CombinedCitizenDeliveryOrder {
  final String baseRequestId;
  final String cycleId;
  final String beneficiaryId;
  final String deliveryMode;
  final String? deliveryAddress;
  final double deliveryDistanceKm;
  final double transportFeeInr;
  final String deliveryStatus;
  final String? citizenConfirmedAt;
  final String? disputeReason;
  final String? registeredFpsName;
  final String? intendedFpsName;
  final String? delayReason;
  final String? expectedDeliveryWindow;
  final String? delayNotifiedAt;
  final List<CitizenDeliveryRecord> items;

  CombinedCitizenDeliveryOrder({
    required this.baseRequestId,
    required this.cycleId,
    required this.beneficiaryId,
    required this.deliveryMode,
    this.deliveryAddress,
    required this.deliveryDistanceKm,
    required this.transportFeeInr,
    required this.deliveryStatus,
    this.citizenConfirmedAt,
    this.disputeReason,
    this.registeredFpsName,
    this.intendedFpsName,
    this.delayReason,
    this.expectedDeliveryWindow,
    this.delayNotifiedAt,
    required this.items,
  });

  CitizenDeliveryRecord? get riceItem =>
      items.where((i) => i.commodity.toLowerCase() == 'rice').firstOrNull;
  CitizenDeliveryRecord? get wheatItem =>
      items.where((i) => i.commodity.toLowerCase() == 'wheat').firstOrNull;

  double get authorizedRiceKg => riceItem != null
      ? (riceItem!.authorizedQuantityKg > 0
          ? riceItem!.authorizedQuantityKg
          : riceItem!.requestedQuantityKg)
      : 0.0;

  double get authorizedWheatKg => wheatItem != null
      ? (wheatItem!.authorizedQuantityKg > 0
          ? wheatItem!.authorizedQuantityKg
          : wheatItem!.requestedQuantityKg)
      : 0.0;

  double get totalQuantityKg => authorizedRiceKg + authorizedWheatKg;

  bool get isDelayed =>
      deliveryStatus.toUpperCase() == 'DELAYED' ||
      deliveryStatus.toUpperCase() == 'STOCK_DELAYED' ||
      items.any((i) =>
          i.deliveryStatus.toUpperCase() == 'DELAYED' ||
          i.deliveryStatus.toUpperCase() == 'STOCK_DELAYED');
}

class BeneficiaryHomeScreen extends StatefulWidget {
  final String beneficiaryId;
  final ApiService? apiService;

  const BeneficiaryHomeScreen({
    super.key,
    required this.beneficiaryId,
    this.apiService,
  });

  @override
  State<BeneficiaryHomeScreen> createState() => _BeneficiaryHomeScreenState();
}

class _BeneficiaryHomeScreenState extends State<BeneficiaryHomeScreen> {
  late final ApiService _apiService;
  Beneficiary? _beneficiary;
  BeneficiaryEntitlementSummary? _entitlement;
  List<IntentRecord> _activeIntents = [];
  List<CitizenDeliveryRecord> _deliveryRecords = [];
  Map<String, dynamic>? _planningCycleState;
  bool _isLoading = true;
  String? _errorMessage;

  List<FpsShop> _fpsList = [];

  // Household-based Entitlement State
  int _eligibleMembersCount = 1;
  double _distributedQuantityKg = 0.0;
  double _remainingBalanceKg = 0.0;
  bool _isBiometricVerified = false;
  bool _userSubmittedChoice = false;

  // Active Request ETA Countdown State
  Timer? _etaCountdownTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();

    // Enable Voice Assistant automatically for authenticated beneficiary
    VoiceAssistantService.instance.enableBeneficiaryVoiceMode();

    _loadBeneficiaryData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        VoiceAssistantService.instance.guideBeneficiaryPostLoginWelcome();
      }
    });

    _setupVoiceCommandRouter();
  }

  void _setupVoiceCommandRouter() {
    VoiceAssistantService.instance.onCommandRecognized = (cmd) {
      if (!mounted) return;
      final resolution = BeneficiaryVoiceCommandRouter.resolve(cmd);
      final lang = LanguageController.instance.currentLanguage;

      final hasCompletedDelivery = _deliveryRecords.any((r) => r.deliveryStatus == 'DELIVERY_CONFIRMED' || r.citizenConfirmedAt != null);
      final isReceived = _entitlement?.rationReceivedForCycle == true || hasCompletedDelivery;

      switch (resolution.intent) {
        case BeneficiaryVoiceIntent.languageHindi:
          LanguageController.instance.setLanguage(AppLanguage.hindi);
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          break;

        case BeneficiaryVoiceIntent.languageKannada:
          LanguageController.instance.setLanguage(AppLanguage.kannada);
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          break;

        case BeneficiaryVoiceIntent.languageEnglish:
          LanguageController.instance.setLanguage(AppLanguage.english);
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          break;

        case BeneficiaryVoiceIntent.grainAtm:
          if (isReceived) {
            VoiceAssistantService.instance.guideAtmAlreadyReceived();
            return;
          }
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          _navigateToGrainAtm();
          break;

        case BeneficiaryVoiceIntent.demandSelection:
          if (isReceived) {
            VoiceAssistantService.instance.guideCycleAlreadyReceived();
            return;
          }
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          _navigateToIntentSelection();
          break;

        case BeneficiaryVoiceIntent.rationShop:
          final homeFps = _beneficiary?.registeredFpsName ?? 'Malleshwaram Seva Kendra';
          final activeFps = _deliveryRecords.isNotEmpty
              ? (_deliveryRecords.first.intendedFpsName ?? _deliveryRecords.first.registeredFpsName ?? homeFps)
              : (_activeIntents.isNotEmpty ? _activeIntents.first.intendedFpsName : homeFps);
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          _showFpsRouteTrackingModal(activeFps ?? homeFps);
          break;

        case BeneficiaryVoiceIntent.tracking:
          String deliveryStepText;
          if (_deliveryRecords.isEmpty) {
            deliveryStepText = lang == AppLanguage.hindi
                ? 'मांग दर्ज करने की प्रतीक्षा है'
                : lang == AppLanguage.kannada
                    ? 'ಆಯ್ಕೆ ಸಲ್ಲಿಸಲು ಕಾಯಲಾಗುತ್ತಿದೆ'
                    : 'Awaiting your choice selection';
          } else if (isReceived) {
            deliveryStepText = lang == AppLanguage.hindi
                ? 'राशन सफलतापूर्वक प्राप्त हुआ ✓'
                : lang == AppLanguage.kannada
                    ? 'ಪಡಿತರ ಯಶಸ್ವಿಯಾಗಿ ತಲುಪಿದೆ ✓'
                    : 'Ration Received Successfully ✓';
          } else if (_deliveryRecords.any((r) => r.deliveryStatus == 'DELIVERED')) {
            deliveryStepText = lang == AppLanguage.hindi
                ? 'दुकान पर उपलब्ध • लेने के लिए तैयार'
                : lang == AppLanguage.kannada
                    ? 'ಅಂಗಡಿಯಲ್ಲಿ ಲಭ್ಯ • ತೆಗೆದುಕೊಳ್ಳಲು ಸಿದ್ಧ'
                    : 'Ready for pickup at shop';
          } else if (_deliveryRecords.any((r) => r.deliveryStatus == 'OUT_FOR_DELIVERY')) {
            deliveryStepText = lang == AppLanguage.hindi
                ? 'राशन दुकान के लिए रवाना हो चुका है'
                : lang == AppLanguage.kannada
                    ? 'ಪಡಿತರ ರವಾನೆಯಾಗಿದೆ'
                    : 'Dispatched / In transit to shop';
          } else {
            deliveryStepText = lang == AppLanguage.hindi
                ? 'गोदाम में राशन पैक हो रहा है'
                : lang == AppLanguage.kannada
                    ? 'ಗೋದಾಮಿನಲ್ಲಿ ಪ್ಯಾಕ್ ಆಗುತ್ತಿದೆ'
                    : 'Grain allocation being prepared';
          }
          VoiceAssistantService.instance.guideTracking(deliveryStepText);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(deliveryStepText),
              backgroundColor: AppConstants.primaryNavy,
              duration: const Duration(seconds: 4),
            ),
          );
          break;

        case BeneficiaryVoiceIntent.helpFeedback:
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          SimpleBeneficiaryFeedbackDialog.show(
            context,
            beneficiaryId: widget.beneficiaryId,
            activeRequestId: _deliveryRecords.isNotEmpty ? _deliveryRecords.first.requestId : null,
            registeredFpsId: _beneficiary?.registeredFpsId,
            apiService: _apiService,
            onFeedbackSubmitted: _loadBeneficiaryData,
          );
          break;

        case BeneficiaryVoiceIntent.historyReceipts:
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          _navigateToIntentHistory();
          break;

        case BeneficiaryVoiceIntent.profileCard:
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          _showBeneficiaryProfileModal();
          break;

        case BeneficiaryVoiceIntent.repeatHelp:
          VoiceAssistantService.instance.guideBeneficiaryPostLoginWelcome();
          break;

        case BeneficiaryVoiceIntent.unknown:
          VoiceAssistantService.instance.speakLocalized(
            hiText: resolution.confirmationHi,
            knText: resolution.confirmationKn,
            enText: resolution.confirmationEn,
          );
          break;
      }
    };
  }

  @override
  void dispose() {
    VoiceAssistantService.instance.onCommandRecognized = null;
    VoiceAssistantService.instance.stopListening();
    _etaCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBeneficiaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ben = await _apiService.fetchBeneficiaryDetail(widget.beneficiaryId);
      final ent = await _apiService.fetchBeneficiaryEntitlementSummary(
        widget.beneficiaryId,
        cycleId: '2026-09',
      );
      final intents = await _apiService.fetchBeneficiaryIntents(
        widget.beneficiaryId,
        cycleId: '2026-09',
      );
      final deliveries = await _apiService.fetchBeneficiaryDeliveryRecords(
        widget.beneficiaryId,
        cycleId: '2026-09',
      );
      List<FpsShop> fpsList = [];
      try {
        fpsList = await _apiService.fetchFpsList();
      } catch (_) {}
      Map<String, dynamic>? cycleState;
      try {
        cycleState = await _apiService.fetchChoiceWindowStatus(cycleId: '2026-09');
      } catch (_) {
        cycleState = null;
      }

      if (mounted) {
        setState(() {
          _beneficiary = ben;
          _entitlement = ent;
          _activeIntents = intents;
          _deliveryRecords = deliveries;
          _fpsList = fpsList;
          _planningCycleState = cycleState;
          _userSubmittedChoice = false;
          _eligibleMembersCount = ent.familyMembersCount > 0 ? ent.familyMembersCount : 1;
          final statutoryTotal = ent.totalEligibleBalanceKg > 0
              ? ent.totalEligibleBalanceKg
              : (ent.statutoryEntitlementRiceKg + ent.statutoryEntitlementWheatKg);
          final totalEligible = statutoryTotal > 0 ? statutoryTotal : (_eligibleMembersCount * 5.0);
          _remainingBalanceKg = (totalEligible - _distributedQuantityKg).clamp(0.0, totalEligible);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load official beneficiary data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToIntentSelection({String initialMode = 'FPS_COLLECTION'}) async {
    if (_beneficiary == null) return;

    // When ration is already received, navigate to IntentSelectionScreen so the user
    // sees the prominent disabled selection view and hears the audio explanation.

    // Beneficiary eligibility for choice selection is governed strictly per-beneficiary
    // based on whether they have already received/confirmed ration for the active cycle.

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntentSelectionScreen(
          beneficiary: _beneficiary!,
          apiService: _apiService,
          initialDeliveryMode: initialMode,
          initialEligibleMembersCount: _eligibleMembersCount,
        ),
      ),
    );

    if (result == true) {
      setState(() => _userSubmittedChoice = true);
      _loadBeneficiaryData();
    } else {
      _loadBeneficiaryData();
    }
  }

  void _navigateToIntentHistory() {
    if (_beneficiary == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntentHistoryScreen(
          beneficiary: _beneficiary!,
          apiService: _apiService,
        ),
      ),
    );
  }

  void _navigateToGrainAtm() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GrainAtmWelcomeScreen(
          beneficiary: _beneficiary,
          beneficiaryId: widget.beneficiaryId,
        ),
      ),
    );
    _loadBeneficiaryData();
  }

  List<CombinedCitizenDeliveryOrder> _getCombinedDeliveryOrders() {
    if (_deliveryRecords.isEmpty) return [];

    final Map<String, List<CitizenDeliveryRecord>> grouped = {};
    for (final r in _deliveryRecords) {
      String baseId = r.requestId;
      if (baseId.endsWith('-R') || baseId.endsWith('-W')) {
        baseId = baseId.substring(0, baseId.length - 2);
      }
      grouped.putIfAbsent(baseId, () => []).add(r);
    }

    final List<CombinedCitizenDeliveryOrder> result = [];
    for (final entry in grouped.entries) {
      final baseId = entry.key;
      final items = entry.value;
      final first = items.first;

      // Status determination
      String statusKey = first.deliveryStatus;
      final anyConfirmed = items.any((i) => i.citizenConfirmedAt != null);
      final anyDispute = items.any((i) => i.disputeReason != null);

      if (anyConfirmed) {
        statusKey = 'DELIVERY_CONFIRMED';
      } else if (anyDispute) {
        statusKey = 'DELIVERY_DISPUTE';
      } else if (items.any((i) => i.deliveryStatus == 'DELAYED' || i.deliveryStatus == 'STOCK_DELAYED')) {
        statusKey = 'DELAYED';
      } else {
        if (items.any((i) => i.deliveryStatus == 'DELIVERED')) {
          statusKey = 'DELIVERED';
        } else if (items.any((i) => i.deliveryStatus == 'OUT_FOR_DELIVERY')) {
          statusKey = 'OUT_FOR_DELIVERY';
        } else if (items.any((i) => i.deliveryStatus == 'ALLOCATED')) {
          statusKey = 'ALLOCATED';
        } else {
          statusKey = first.deliveryStatus;
        }
      }

      final disputeNotes = items
          .map((i) => i.disputeReason)
          .where((d) => d != null && d.isNotEmpty)
          .toSet()
          .join(' • ');

      final delayReason = items.map((i) => i.delayReason).firstWhere((d) => d != null && d.isNotEmpty, orElse: () => null);
      final expectedWindow = items.map((i) => i.expectedDeliveryWindow).firstWhere((w) => w != null && w.isNotEmpty, orElse: () => null);
      final delayNotifiedAt = items.map((i) => i.delayNotifiedAt).firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null);

      result.add(
        CombinedCitizenDeliveryOrder(
          baseRequestId: baseId,
          cycleId: first.cycleId,
          beneficiaryId: first.beneficiaryId,
          deliveryMode: first.deliveryMode,
          deliveryAddress: first.deliveryAddress,
          deliveryDistanceKm: first.deliveryDistanceKm,
          transportFeeInr: first.transportFeeInr,
          deliveryStatus: statusKey,
          citizenConfirmedAt: first.citizenConfirmedAt,
          disputeReason: disputeNotes.isNotEmpty ? disputeNotes : null,
          registeredFpsName: first.registeredFpsName,
          intendedFpsName: first.intendedFpsName,
          delayReason: delayReason,
          expectedDeliveryWindow: expectedWindow,
          delayNotifiedAt: delayNotifiedAt,
          items: items,
        ),
      );
    }

    return result;
  }

  void _confirmCombinedOrderReceipt(CombinedCitizenDeliveryOrder order) async {
    setState(() => _isLoading = true);
    try {
      for (final item in order.items) {
        final expectedQty = item.authorizedQuantityKg > 0
            ? item.authorizedQuantityKg
            : item.requestedQuantityKg;
        await _apiService.confirmCitizenDelivery(
          beneficiaryId: widget.beneficiaryId,
          requestId: item.requestId,
          confirmationStatus: 'DELIVERY_CONFIRMED',
          receivedRiceKg: item.commodity.toLowerCase() == 'rice' ? expectedQty : 0.0,
          receivedWheatKg: item.commodity.toLowerCase() == 'wheat' ? expectedQty : 0.0,
        );
      }
      await _loadBeneficiaryData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('delivery.confirm_success')),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirmation failed: $e'), backgroundColor: AppConstants.dangerRed),
        );
      }
    }
  }

  void _showCombinedDeliveryDisputeModal(CombinedCitizenDeliveryOrder order) {
    final riceItem = order.riceItem;
    final wheatItem = order.wheatItem;

    final double expectedRice = order.authorizedRiceKg;
    final double expectedWheat = order.authorizedWheatKg;

    final riceQtyCtrl = TextEditingController(text: expectedRice.toStringAsFixed(1));
    final wheatQtyCtrl = TextEditingController(text: expectedWheat.toStringAsFixed(1));
    final notesCtrl = TextEditingController();
    bool isProcessing = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLarge)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final actualRice = double.tryParse(riceQtyCtrl.text) ?? expectedRice;
          final actualWheat = double.tryParse(wheatQtyCtrl.text) ?? expectedWheat;
          final shortfallRice = (expectedRice - actualRice).clamp(0.0, 999.0);
          final shortfallWheat = (expectedWheat - actualWheat).clamp(0.0, 999.0);

          final quotaSummary = '${expectedRice > 0 ? "${expectedRice.toStringAsFixed(1)} ${tr('commodity.kg')} ${tr('commodity.rice')}" : ""}${expectedRice > 0 && expectedWheat > 0 ? " + " : ""}${expectedWheat > 0 ? "${expectedWheat.toStringAsFixed(1)} ${tr('commodity.kg')} ${tr('commodity.wheat')}" : ""}';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.report_problem_outlined, color: AppConstants.dangerRed, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            tr('dispute.modal_title'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('dispute.order_ref', params: {'orderId': order.baseRequestId, 'quota': quotaSummary}),
                    style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  if (shortfallRice > 0 || shortfallWheat > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('dispute.detected_shortfall'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppConstants.dangerRed)),
                          const SizedBox(height: 4),
                          if (shortfallRice > 0)
                            Text(
                              tr('dispute.rice_shortfall', params: {'qty': shortfallRice.toStringAsFixed(1)}),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppConstants.dangerRed),
                            ),
                          if (shortfallWheat > 0)
                            Text(
                              tr('dispute.wheat_shortfall', params: {'qty': shortfallWheat.toStringAsFixed(1)}),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppConstants.dangerRed),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (riceItem != null) ...[
                    TextField(
                      controller: riceQtyCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: tr('dispute.actual_rice_label', params: {'expected': expectedRice.toStringAsFixed(1)}),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.scale_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (wheatItem != null) ...[
                    TextField(
                      controller: wheatQtyCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: tr('dispute.actual_wheat_label', params: {'expected': expectedWheat.toStringAsFixed(1)}),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.scale_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: tr('dispute.remarks_label'),
                      hintText: tr('dispute.remarks_hint'),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (modalError != null) ...[
                    const SizedBox(height: 8),
                    Text(modalError!, style: const TextStyle(color: AppConstants.dangerRed, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            if (notesCtrl.text.trim().isEmpty) {
                              setModalState(() => modalError = 'Please provide details describing the discrepancy.');
                              return;
                            }
                            setModalState(() {
                              isProcessing = true;
                              modalError = null;
                            });

                            try {
                              for (final item in order.items) {
                                final isR = item.commodity.toLowerCase() == 'rice';
                                final actualVal = isR ? actualRice : actualWheat;
                                await _apiService.confirmCitizenDelivery(
                                  beneficiaryId: widget.beneficiaryId,
                                  requestId: item.requestId,
                                  confirmationStatus: 'DELIVERY_DISPUTE',
                                  receivedRiceKg: isR ? actualVal : 0.0,
                                  receivedWheatKg: !isR ? actualVal : 0.0,
                                  disputeNotes: notesCtrl.text.trim(),
                                );
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _loadBeneficiaryData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr('dispute.success')),
                                  backgroundColor: AppConstants.accentAmber,
                                ),
                              );
                            } catch (e) {
                              setModalState(() {
                                isProcessing = false;
                                modalError = 'Submission failed: $e';
                              });
                            }
                          },
                    icon: isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      isProcessing ? tr('dispute.submitting') : tr('dispute.btn_submit'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.dangerRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // SIMPLE BENEFICIARY ENTITLEMENT CARD (PREDOMINANTLY WHITE THEME)
  // -------------------------------------------------------------
  // -------------------------------------------------------------
  // SIMPLE BENEFICIARY ENTITLEMENT CARD (PREDOMINANTLY WHITE THEME)
  // -------------------------------------------------------------
  Widget _buildSimpleEntitlementCard() {
    final isHindi = VoiceAssistantService.instance.isHindi;
    final isKannada = VoiceAssistantService.instance.isKannada;
    final isElderly = VoiceAssistantService.instance.isElderlyMode;

    final homeFpsName = _beneficiary?.registeredFpsName ?? 'Malleshwaram Seva Kendra';
    final activeFpsName = _deliveryRecords.isNotEmpty
        ? (_deliveryRecords.first.intendedFpsName ?? _deliveryRecords.first.registeredFpsName ?? homeFpsName)
        : (_activeIntents.isNotEmpty ? _activeIntents.first.intendedFpsName : homeFpsName);

    final riceTotal = _entitlement != null ? _entitlement!.statutoryEntitlementRiceKg : (_eligibleMembersCount * 4.0);
    final wheatTotal = _entitlement != null ? _entitlement!.statutoryEntitlementWheatKg : (_eligibleMembersCount * 1.0);
    final totalEntitlementKg = _entitlement != null && _entitlement!.totalEligibleBalanceKg > 0
        ? _entitlement!.totalEligibleBalanceKg
        : (riceTotal + wheatTotal);

    final hasCompletedDelivery = _deliveryRecords.any((r) => r.deliveryStatus == 'DELIVERY_CONFIRMED' || r.citizenConfirmedAt != null);
    final hasPlanLocked = _entitlement?.rationReceivedForCycle == true || _userSubmittedChoice || _activeIntents.isNotEmpty || hasCompletedDelivery;
    final isReceived = _entitlement?.rationReceivedForCycle == true || hasCompletedDelivery;

    return Container(
      key: const ValueKey('card_simple_entitlement'),
      padding: EdgeInsets.all(isElderly ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isElderly ? 18 : 14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🌾', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          isHindi
                              ? 'आपका मासिक राशन'
                              : isKannada
                                  ? 'ನಿಮ್ಮ ಮಾಸಿಕ ಪಡಿತರ'
                                  : 'Your Monthly Ration',
                          style: TextStyle(
                            fontSize: isElderly ? 18 : 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F2942),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('entitlement.family_title'),
                      style: TextStyle(
                        fontSize: isElderly ? 13 : 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  isHindi ? '₹0 मुफ्त कोटा' : isKannada ? '₹0 ಉಚಿತ' : '100% Free (NFSA)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Rice Tile
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🍚', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            isHindi ? 'चावल' : isKannada ? 'ಅಕ್ಕಿ' : 'Rice',
                            style: TextStyle(
                              fontSize: isElderly ? 14 : 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${riceTotal.toStringAsFixed(0)} kg',
                        style: TextStyle(
                          fontSize: isElderly ? 26 : 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Wheat Tile
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🌾', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            isHindi ? 'गेहूं' : isKannada ? 'ಗೋಧಿ' : 'Wheat',
                            style: TextStyle(
                              fontSize: isElderly ? 14 : 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${wheatTotal.toStringAsFixed(0)} kg',
                        style: TextStyle(
                          fontSize: isElderly ? 26 : 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isHindi
                    ? 'कुल कोटा: ${totalEntitlementKg.toStringAsFixed(0)} किलो • ${_eligibleMembersCount} सदस्य पंजीकृत'
                    : isKannada
                        ? 'ಒಟ್ಟು ಕೋಟಾ: ${totalEntitlementKg.toStringAsFixed(0)} ಕೆಜಿ • ${_eligibleMembersCount} ಸದಸ್ಯರು'
                        : 'Total Entitlement: ${totalEntitlementKg.toStringAsFixed(0)} kg • ${_eligibleMembersCount} family members',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Integrated Citizen Action / Reassurance Button
          ElevatedButton(
            onPressed: () {
              if (isReceived) {
                VoiceAssistantService.instance.guideCycleAlreadyReceived();
              } else if (hasPlanLocked) {
                _showFpsRouteTrackingModal(activeFpsName ?? homeFpsName);
              } else {
                _navigateToIntentSelection();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isReceived
                  ? const Color(0xFF15803D)
                  : hasPlanLocked
                      ? const Color(0xFF0F2942)
                      : const Color(0xFF15803D),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isElderly ? 16 : 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0.5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isReceived
                      ? Icons.check_circle_rounded
                      : hasPlanLocked
                          ? Icons.lock_outline_rounded
                          : Icons.how_to_reg_rounded,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isReceived
                      ? (isHindi ? '✓ राशन मिल चुका है' : isKannada ? '✓ ಪಡಿತರ ಸ್ವೀಕರಿಸಲಾಗಿದೆ' : '✓ Ration Received')
                      : hasPlanLocked
                          ? (isHindi ? '🔒 पसंद दर्ज है ($activeFpsName) • विवरण देखें' : isKannada ? '🔒 ಆಯ್ಕೆ ದಾಖಲಾಗಿದೆ ($activeFpsName) • ವಿವರ ನೋಡಿ' : '🔒 Request Locked • $activeFpsName')
                          : tr('simple.btn_select_choice'),
                  style: TextStyle(
                    fontSize: isElderly ? 16 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBeneficiaryProfileModal() {
    if (_beneficiary == null) return;
    final b = _beneficiary!;
    final cardLabel = _entitlement?.cardLabel ?? 'Priority Household (PHH)';
    final isHindi = VoiceAssistantService.instance.isHindi;
    final isKannada = VoiceAssistantService.instance.isKannada;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF15803D),
              child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    b.nameForDemo,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F2942)),
                  ),
                  Text(
                    b.pseudonymousBeneficiaryId,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBeneficiaryProfileCard(),
            const SizedBox(height: 12),
            _buildProfileModalRow(isHindi ? 'योजना का प्रकार' : isKannada ? 'ಯೋಜನೆ' : 'Scheme', cardLabel),
            _buildProfileModalRow(isHindi ? 'पंजीकृत दुकान' : isKannada ? 'ನೋಂದಾಯಿತ ಅಂಗಡಿ' : 'Registered Shop', b.registeredFpsName ?? b.registeredFpsId),
            _buildProfileModalRow(isHindi ? 'परिवार के सदस्य' : isKannada ? 'ಕುಟುಂಬದ ಸದಸ್ಯರು' : 'Family Members', '$_eligibleMembersCount सदस्य'),
            _buildProfileModalRow(isHindi ? 'आधार स्थिति' : isKannada ? 'ಆಧಾರ್ ಸ್ಥಿತಿ' : 'Aadhaar Status', _isBiometricVerified ? '✓ बायोमेट्रिक लिंक (Active)' : '✓ बायोमेट्रिक लिंक (Active)'),
            _buildProfileModalRow(isHindi ? 'मासिक कोटा' : isKannada ? 'ಮಾಸಿಕ ಕೋಟಾ' : 'Monthly Quota', '${(_eligibleMembersCount * 5.0).toStringAsFixed(0)} kg (100% Free)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isHindi ? 'बंद करें' : isKannada ? 'ಮುಚ್ಚಿ' : 'Close', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F2942)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildGovernmentAppBar(),
          // floatingActionButton removed in favor of unified VoiceAssistantBanner
          floatingActionButton: null,
          body: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2.5, color: AppConstants.primaryNavy),
                      const SizedBox(height: 16),
                      Text(tr('profile.loading'), style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadBeneficiaryData,
                              icon: const Icon(Icons.refresh),
                              label: Text(tr('profile.error_retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBeneficiaryData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.space20, vertical: AppConstants.space20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Persistent Voice Assistant Spoken Instruction Banner (with Repeat button)
                                const VoiceAssistantBanner(),
                                const SizedBox(height: AppConstants.space16),

                                // 1. Clean Simple Entitlement Summary (चावल 15kg, गेहूं 5kg) & Plan Status
                                _buildSimpleEntitlementCard(),
                                const SizedBox(height: AppConstants.space16),

                                // 2. Authoritative Planning Cycle & Choice Window Visualizer (21-24 तारीख)
                                _buildPlanningCycleBanner(),
                                const SizedBox(height: AppConstants.space16),

                                // 3. Current Request / Delivery Status (5-Stage Timeline & Delay Alerts)
                                if (_deliveryRecords.isNotEmpty) ...[
                                  _buildCurrentDeliveryStatusSection(),
                                  const SizedBox(height: AppConstants.space16),
                                ],

                                // 4. THE 4 HERO BENEFICIARY ACTION CARDS (ACCESSIBLE & VISUAL 2x2 UX)
                                _buildFourHeroCardsSection(),
                                const SizedBox(height: AppConstants.space16),

                                // 5. Plan Your Upcoming Collection (Only shown if choice not yet submitted)
                                _buildPlanCollectionSection(),

                                // 6. Eligible Household Members Selector (5 kg per person statutory quota)
                                _buildHouseholdMembersSelectorCard(),
                                const SizedBox(height: AppConstants.space16),

                                // 7. Recent Distribution History (Compact list rows)
                                _buildRecentDistributionHistorySection(),
                                const SizedBox(height: AppConstants.space20),

                                // Statutory Footer Reassurance
                                Center(
                                  child: Text(
                                    '${tr('app.gov_badge')}\n${tr('commodity.entitled_free')}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: Colors.grey.shade500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppConstants.space16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // THE 4 HERO BENEFICIARY ACTION CARDS (ACCESSIBLE & VISUAL UX)
  // -------------------------------------------------------------
  Widget _buildFourHeroCardsSection() {
    final isHindi = VoiceAssistantService.instance.isHindi;
    final isKannada = VoiceAssistantService.instance.isKannada;
    final isElderly = VoiceAssistantService.instance.isElderlyMode;

    final homeFpsName = _beneficiary?.registeredFpsName ?? 'Malleshwaram Seva Kendra';
    final activeFpsName = _deliveryRecords.isNotEmpty
        ? (_deliveryRecords.first.intendedFpsName ?? _deliveryRecords.first.registeredFpsName ?? homeFpsName)
        : (_activeIntents.isNotEmpty ? _activeIntents.first.intendedFpsName : homeFpsName);

    final hasCompletedDelivery = _deliveryRecords.any((r) => r.deliveryStatus == 'DELIVERY_CONFIRMED' || r.citizenConfirmedAt != null);
    final hasPlanLocked = _entitlement?.rationReceivedForCycle == true || _userSubmittedChoice || _activeIntents.isNotEmpty || hasCompletedDelivery;
    final isReceived = _entitlement?.rationReceivedForCycle == true || hasCompletedDelivery;

    // Delivery status mapping for simple presentation
    String deliveryStepText;
    int activeStepIndex = 1;
    if (_deliveryRecords.isEmpty && !hasPlanLocked) {
      deliveryStepText = isHindi ? 'पसंद दर्ज करने की प्रतीक्षा' : isKannada ? 'ಆಯ್ಕೆ ಸಲ್ಲಿಸಲು ಕಾಯಲಾಗುತ್ತಿದೆ' : 'Awaiting your choice selection';
      activeStepIndex = 0;
    } else if (isReceived) {
      deliveryStepText = isHindi ? 'राशन सफलतापूर्वक प्राप्त हुआ ✓' : isKannada ? 'ಪಡಿತರ ಯಶಸ್ವಿಯಾಗಿ ತಲುಪಿದೆ ✓' : 'Ration Received Successfully ✓';
      activeStepIndex = 5;
    } else if (_deliveryRecords.any((r) => r.deliveryStatus == 'DELIVERED')) {
      deliveryStepText = isHindi ? 'दुकान पर उपलब्ध • लेने के लिए तैयार' : isKannada ? 'ಅಂಗಡಿಯಲ್ಲಿ ಲಭ್ಯ • ತೆಗೆದುಕೊಳ್ಳಲು ಸಿದ್ಧ' : 'Ready for pickup at shop';
      activeStepIndex = 4;
    } else if (_deliveryRecords.any((r) => r.deliveryStatus == 'OUT_FOR_DELIVERY')) {
      deliveryStepText = isHindi ? 'राशन दुकान के लिए रवाना हो चुका है' : isKannada ? 'ಪಡಿತರ ರವಾನೆಯಾಗಿದೆ' : 'Dispatched / In transit to shop';
      activeStepIndex = 3;
    } else {
      deliveryStepText = isHindi ? 'गोदाम में राशन पैक हो रहा है' : isKannada ? 'ಗೋದಾಮಿನಲ್ಲಿ ಪ್ಯಾಕ್ ಆಗುತ್ತಿದೆ' : 'Grain allocation being prepared';
      activeStepIndex = 2;
    }

    // 1. MY RATION SHOP (मेरी राशन दुकान)
    final cardShop = _buildHeroActionCard(
      key: const ValueKey('card_hero_my_shop'),
      emoji: '🏪',
      icon: Icons.storefront_rounded,
      iconColor: AppConstants.primaryNavy,
      iconBg: const Color(0xFFEFF6FF),
      title: isHindi
          ? 'मेरी राशन दुकान'
          : isKannada
              ? 'ನನ್ನ ಪಡಿತರ ಅಂಗಡಿ'
              : 'My Ration Shop',
      subtitle: activeFpsName ?? homeFpsName,
      tagText: isHindi ? '🟢 आज खुली है' : isKannada ? '🟢 ತೆರೆದಿದೆ' : '🟢 Open Today',
      tagColor: const Color(0xFF15803D),
      tagBg: const Color(0xFFF0FDF4),
      subDetail: isHindi
          ? '📍 0.6 km • 🚶 लगभग 10 मिनट पैदल रास्ता'
          : isKannada
              ? '📍 0.6 ಕಿಮೀ • 🚶 ಸುಮಾರು 10 ನಿಮಿಷ'
              : '📍 0.6 km • 🚶 ~10 mins walking distance',
      btnLabel: isHindi
          ? 'दुकान का रास्ता और नक्शा देखें 🗺️'
          : isKannada
              ? 'ಅಂಗಡಿ ದಾರಿ ಮತ್ತು ನಕ್ಷೆ ನೋಡಿ 🗺️'
              : 'View Shop Location & Map 🗺️',
      btnBg: AppConstants.primaryNavy,
      onBtnTap: () => _showFpsRouteTrackingModal(activeFpsName ?? homeFpsName),
      onSpeak: () {
        VoiceAssistantService.instance.speakLocalized(
          hiText: 'आपकी राशन दुकान है ${activeFpsName ?? homeFpsName}। दूरी लगभग 600 मीटर है और दुकान आज सुबह 8:30 से दोपहर 1:30 तक खुली है।',
          knText: 'ನಿಮ್ಮ ಪಡಿತರ ಅಂಗಡಿ ${activeFpsName ?? homeFpsName}. ದೂರ ಸುಮಾರು 600 ಮೀಟರ್.',
          enText: 'Your ration shop is ${activeFpsName ?? homeFpsName}. Distance is approximately 0.6 kilometers and the shop is open today.',
        );
      },
      isElderly: isElderly,
    );

    // 2. TRACK MY RATION (राशन कहां पहुंचा?)
    final cardStatus = _buildHeroActionCard(
      key: const ValueKey('card_hero_ration_status'),
      emoji: '🚚',
      icon: Icons.local_shipping_rounded,
      iconColor: const Color(0xFF2563EB),
      iconBg: const Color(0xFFEFF6FF),
      title: isHindi
          ? 'राशन कहां पहुंचा? (ट्रैकिंग)'
          : isKannada
              ? 'ಪಡಿತರ ಎಲ್ಲಿಗೆ ತಲುಪಿದೆ? (ಟ್ರ್ಯಾಕಿಂಗ್)'
              : 'Track My Ration',
      subtitle: deliveryStepText,
      customChild: _buildSimpleJourneyStepper(activeStepIndex, isHindi, isKannada),
      btnLabel: isReceived
          ? (isHindi ? '✓ राशन प्राप्ति दर्ज है' : isKannada ? '✓ ಸ್ವೀಕೃತಿ ದಾಖಲಾಗಿದೆ' : '✓ Receipt Confirmed')
          : (activeStepIndex >= 4
              ? (isHindi ? 'राशन मिल गया? बताएं 👉' : isKannada ? 'ಪಡಿತರ ಸಿಕ್ಕಿತೇ? ತಿಳಿಸಿ 👉' : 'Confirm Receipt 👉')
              : (isHindi ? 'पूरी स्थिति देखें 👉' : isKannada ? 'ಸಂಪೂರ್ಣ ಸ್ಥಿತಿ ನೋಡಿ 👉' : 'Track My Ration 👉')),
      btnBg: activeStepIndex >= 4 ? const Color(0xFF15803D) : const Color(0xFF2563EB),
      onBtnTap: () {
        VoiceAssistantService.instance.guideTracking(deliveryStepText);
        if (activeStepIndex >= 4 && !isReceived) {
          SimpleBeneficiaryFeedbackDialog.show(
            context,
            beneficiaryId: widget.beneficiaryId,
            activeRequestId: _deliveryRecords.isNotEmpty ? _deliveryRecords.first.requestId : null,
            registeredFpsId: _beneficiary?.registeredFpsId,
            apiService: _apiService,
            onFeedbackSubmitted: _loadBeneficiaryData,
          );
        } else if (_deliveryRecords.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(deliveryStepText),
              backgroundColor: AppConstants.primaryNavy,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onSpeak: () {
        VoiceAssistantService.instance.guideTracking(deliveryStepText);
      },
      isElderly: isElderly,
    );

    // 3. RATION VENDING MACHINE (राशन वेंडिंग मशीन / ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್)
    final cardAtm = _buildHeroActionCard(
      key: const ValueKey('card_hero_grain_atm'),
      emoji: '📦',
      icon: Icons.precision_manufacturing_rounded,
      iconColor: const Color(0xFF0D9488),
      iconBg: const Color(0xFFCCFBF1),
      title: isHindi
          ? 'राशन वेंडिंग मशीन'
          : isKannada
              ? 'ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್'
              : 'Ration Vending Machine',
      subtitle: isHindi
          ? 'स्वचालित 24/7 राशन संग्रह'
          : isKannada
              ? 'ಸ್ವಯಂಚಾಲಿತ 24/7 ಪಡಿತರ'
              : 'Automated 24/7 Ration Pickup',
      tagText: isReceived
          ? (isHindi ? 'प्राप्त हुआ' : isKannada ? 'ಸ್ವೀಕರಿಸಲಾಗಿದೆ' : 'Received')
          : (isHindi ? '🟢 चालू • VM-001' : isKannada ? '🟢 ಸಕ್ರಿಯ • VM-001' : '🟢 Ready • VM-001'),
      tagColor: const Color(0xFF0D9488),
      tagBg: const Color(0xFFF0FDFA),
      subDetail: isHindi
          ? '📍 डेमो केंद्र • संपर्क रहित वितरण'
          : isKannada
              ? '📍 ಡೆಮೊ ಕೇಂದ್ರ • ಸಂಪರ್ಕರಹಿತ ವಿತರಣೆ'
              : '📍 Demo Center • Contactless Automated Dispensing',
      btnLabel: isReceived
          ? (isHindi ? '✓ राशन मिल चुका है' : isKannada ? '✓ ಪಡಿತರ ಸ್ವೀಕರಿಸಲಾಗಿದೆ' : '✓ Ration Received')
          : (isHindi ? 'वेंडिंग मशीन से लें 📦' : isKannada ? 'ವೆಂಡಿಂಗ್ ಮೆಷಿನ್ ಬಳಸಿ 📦' : 'Use Vending Machine 📦'),
      btnBg: isReceived ? const Color(0xFF15803D) : const Color(0xFF0D9488),
      onBtnTap: () => _navigateToGrainAtm(),
      onSpeak: () {
        if (isReceived) {
          VoiceAssistantService.instance.guideAtmAlreadyReceived();
        } else {
          VoiceAssistantService.instance.speakLocalized(
            hiText: 'राशन वेंडिंग मशीन: स्वचालित मशीन से अपना राशन लेने के लिए वेंडिंग मशीन बटन दबाएं।',
            knText: 'ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್: ಯಂತ್ರದಿಂದ ನಿಮ್ಮ ಪಡಿತರ ಪಡೆಯಲು ವೆಂಡಿಂಗ್ ಮೆಷಿನ್ ಬಟನ್ ಒತ್ತಿ.',
            enText: 'Ration Vending Machine: Tap Use Vending Machine to collect your grains from the automated machine.',
          );
        }
      },
      isElderly: isElderly,
    );

    // 4. HELP & REPORT PROBLEM (मदद और समस्या)
    final cardHelp = _buildHeroActionCard(
      key: const ValueKey('card_hero_help_dispute'),
      emoji: '🆘',
      icon: Icons.support_agent_rounded,
      iconColor: const Color(0xFFDC2626),
      iconBg: const Color(0xFFFEF2F2),
      title: isHindi
          ? 'मदद और समस्या'
          : isKannada
              ? 'ಸಹಾಯ ಮತ್ತು ದೂರು'
              : 'Help & Report Problem',
      subtitle: isHindi
          ? 'कम राशन मिला? दुकान बंद थी? तुरंत बताएं'
          : isKannada
              ? 'ಕಡಿಮೆ ಪಡಿತರ ಸಿಕ್ಕಿತೇ? ಅಂಗಡಿ ಮುಚ್ಚಿತ್ತೇ? ದೂರು ದಾಖಲಿಸಿ'
              : 'Short weight? Shop closed? Quality issue? Report directly to DSO officers',
      tagText: isHindi ? 'अधिकारी जांच करेंगे' : isKannada ? 'ಅಧಿಕಾರಿ ಪರಿಶೀಲನೆ' : 'DSO Triage',
      tagColor: const Color(0xFFB91C1C),
      tagBg: const Color(0xFFFEE2E2),
      btnLabel: isHindi
          ? 'शिकायत या मदद दर्ज करें 💬'
          : isKannada
              ? 'ದೂರು ಸಲ್ಲಿಸಿ 💬'
              : 'Report Issue / Complaint 💬',
      btnBg: const Color(0xFFDC2626),
      onBtnTap: () {
        VoiceAssistantService.instance.guideHelp();
        SimpleBeneficiaryFeedbackDialog.show(
          context,
          beneficiaryId: widget.beneficiaryId,
          activeRequestId: _deliveryRecords.isNotEmpty ? _deliveryRecords.first.requestId : null,
          registeredFpsId: _beneficiary?.registeredFpsId,
          apiService: _apiService,
          onFeedbackSubmitted: _loadBeneficiaryData,
        );
      },
      onSpeak: () {
        VoiceAssistantService.instance.speakLocalized(
          hiText: 'मदद और समस्या: यदि आपको कम राशन मिला है या दुकान बंद थी, तो शिकायत दर्ज करें बटन दबाकर अपनी बात बताएं।',
          knText: 'ಸಹಾಯ ಮತ್ತು ದೂರು: ಕಡಿಮೆ ಪಡಿತರ ಅಥವಾ ಅಂಗಡಿ ಮುಚ್ಚಿದ್ದರೆ, ದೂರು ಸಲ್ಲಿಸಿ ಬಟನ್ ಒತ್ತಿ.',
          enText: 'Help and problem: If you received less ration or the shop was closed, tap report complaint.',
        );
      },
      isElderly: isElderly,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cardShop),
                  const SizedBox(width: 14),
                  Expanded(child: cardStatus),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cardAtm),
                  const SizedBox(width: 14),
                  Expanded(child: cardHelp),
                ],
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cardShop,
              const SizedBox(height: 12),
              cardStatus,
              const SizedBox(height: 12),
              cardAtm,
              const SizedBox(height: 12),
              cardHelp,
            ],
          );
        }
      },
    );
  }

  Widget _buildHeroActionCard({
    Key? key,
    required String emoji,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? subDetail,
    String? tagText,
    Color? tagColor,
    Color? tagBg,
    Widget? customChild,
    required String btnLabel,
    required Color btnBg,
    required VoidCallback onBtnTap,
    required VoidCallback onSpeak,
    required bool isElderly,
  }) {
    return Container(
      key: key,
      padding: EdgeInsets.all(isElderly ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isElderly ? 18 : 14),
        border: Border.all(
          color: iconColor.withValues(alpha: isElderly ? 0.45 : 0.25),
          width: isElderly ? 2.0 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon + Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isElderly ? 52 : 44,
                height: isElderly ? 52 : 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: TextStyle(fontSize: isElderly ? 28 : 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: isElderly ? 18 : 15.5,
                              fontWeight: FontWeight.w900,
                              color: AppConstants.primaryNavy,
                            ),
                          ),
                        ),
                        if (tagText != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: tagBg ?? const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tagText,
                              style: TextStyle(
                                fontSize: isElderly ? 11 : 9.5,
                                fontWeight: FontWeight.w800,
                                color: tagColor ?? AppConstants.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isElderly ? 14 : 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                        height: 1.3,
                      ),
                    ),
                    if (subDetail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subDetail,
                        style: TextStyle(
                          fontSize: isElderly ? 13 : 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (customChild != null) ...[
            const SizedBox(height: 12),
            customChild,
          ],

          const SizedBox(height: 14),

          // Large Touch CTA Button
          ElevatedButton(
            onPressed: onBtnTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isElderly ? 18 : 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
            child: Text(
              btnLabel,
              style: TextStyle(
                fontSize: isElderly ? 17 : 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleJourneyStepper(int activeIndex, bool isHindi, bool isKannada) {
    final stages = [
      {'label': isHindi ? 'पसंद मिली' : isKannada ? 'ಆಯ್ಕೆ ಸಿಕ್ಕಿದೆ' : 'Saved', 'icon': Icons.check_circle_outline},
      {'label': isHindi ? 'तैयारी' : isKannada ? 'ಸಿದ್ಧತೆ' : 'Packed', 'icon': Icons.inventory_2_outlined},
      {'label': isHindi ? 'रवाना' : isKannada ? 'ರವಾನೆ' : 'Dispatched', 'icon': Icons.local_shipping_outlined},
      {'label': isHindi ? 'दुकान पर' : isKannada ? 'ಅಂಗಡಿಗೆ' : 'At Shop', 'icon': Icons.storefront_outlined},
      {'label': isHindi ? 'तैयार' : isKannada ? 'ಸಿದ್ಧ' : 'Ready', 'icon': Icons.task_alt_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: stages.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final step = entry.value;
          final isPastOrActive = idx <= activeIndex;
          final isCurrent = idx == activeIndex;

          final color = isCurrent
              ? const Color(0xFF2563EB)
              : (isPastOrActive ? const Color(0xFF15803D) : const Color(0xFF94A3B8));

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  step['icon'] as IconData,
                  size: isCurrent ? 22 : 18,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  step['label'] as String,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 0b. AUTHORITATIVE PLANNING CYCLE & CHOICE WINDOW VISUALIZER
  Widget _buildPlanningCycleBanner() {
    final planningDay = _planningCycleState?['planning_day'] ?? 22;
    final isOpen = _planningCycleState?['is_open'] ?? true;
    final closingDeadline = _planningCycleState?['closing_deadline'] ?? 'Day 24 (23:59 IST)';

    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isOpen ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Voice Audio Assistance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isOpen ? Icons.event_available_rounded : Icons.lock_clock_rounded,
                      size: 20,
                      color: isOpen ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOpen
                            ? (VoiceAssistantService.instance.isHindi
                                ? 'आपकी अगली राशन की पसंद बताने का समय (21–24 तारीख)'
                                : VoiceAssistantService.instance.isKannada
                                    ? 'ನಿಮ್ಮ ಮುಂದಿನ ಪಡಿತರ ಆಯ್ಕೆ ಸಮಯ (21–24 ನೇ ದಿನಾಂಕ)'
                                    : 'Time to choose next ration (Day 21–24)')
                            : (VoiceAssistantService.instance.isHindi
                                ? 'आपकी पसंद अब दर्ज हो चुकी है 🔒'
                                : VoiceAssistantService.instance.isKannada
                                    ? 'ನಿಮ್ಮ ಆಯ್ಕೆ ಈಗ ದಾಖಲಾಗಿದೆ 🔒'
                                    : 'Your preference is now recorded & locked 🔒'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isOpen ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // small speaker removed

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOpen ? (VoiceAssistantService.instance.isHindi ? 'विंडो खुली है' : 'Open 21–24') : '🔒 Locked',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Planning Days Stepper Track: DAY 21 -> DAY 22 -> DAY 23 -> DAY 24 -> 🔒 DAY 25
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDayStepNode(21, 'Day 21', planningDay, isOpen),
                  _buildStepSeparator(planningDay > 21),
                  _buildDayStepNode(22, 'Day 22', planningDay, isOpen),
                  _buildStepSeparator(planningDay > 22),
                  _buildDayStepNode(23, 'Day 23', planningDay, isOpen),
                  _buildStepSeparator(planningDay > 23),
                  _buildDayStepNode(24, 'Day 24', planningDay, isOpen),
                  _buildStepSeparator(planningDay >= 25),
                  _buildDayStepNode(25, '🔒 Day 25', planningDay, isOpen, isLockDay: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Explanatory Subtitle
          Text(
            isOpen
                ? tr('cycle.window_desc_open')
                : tr('cycle.locked_cannot_edit', params: {'cycle': _planningCycleState?['cycle_id'] ?? '2026-09'}),
            style: TextStyle(
              fontSize: 11.5,
              color: isOpen ? const Color(0xFF166534) : const Color(0xFF7F1D1D),
              height: 1.35,
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 4),
            Text(
              'Deadline: $closingDeadline • Statutory NFSA ration entitlement is 100% safeguarded by government policy.',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayStepNode(int dayNumber, String label, int currentDay, bool isWindowOpen, {bool isLockDay = false}) {
    final isCurrent = (dayNumber == currentDay) || (isLockDay && currentDay >= 25);
    final isPast = (dayNumber < currentDay);

    Color bg;
    Color border;
    Color textColor;

    if (isCurrent) {
      bg = isLockDay ? const Color(0xFF991B1B) : AppConstants.primaryNavy;
      border = isLockDay ? const Color(0xFF7F1D1D) : AppConstants.primaryNavy;
      textColor = Colors.white;
    } else if (isPast) {
      bg = const Color(0xFFE2E8F0);
      border = const Color(0xFFCBD5E1);
      textColor = const Color(0xFF475569);
    } else {
      bg = const Color(0xFFF8FAFC);
      border = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF94A3B8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStepSeparator(bool isCompleted) {
    return Container(
      width: 12,
      height: 2,
      color: isCompleted ? AppConstants.primaryNavy : const Color(0xFFCBD5E1),
    );
  }

  // TOP BAR
  PreferredSizeWidget _buildGovernmentAppBar() {
    final isHindi = VoiceAssistantService.instance.isHindi;
    final isKannada = VoiceAssistantService.instance.isKannada;
    final bName = _beneficiary?.nameForDemo ?? 'Beneficiary';

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0F2942),
      elevation: 0.5,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: const Color(0xFFE2E8F0),
          height: 1.0,
        ),
      ),
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Icon(Icons.shield_rounded, size: 20, color: Color(0xFF15803D)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isHindi ? '👋 नमस्ते, ' : isKannada ? '👋 ನಮಸ್ಕಾರ, ' : '👋 Hello, ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    Flexible(
                      child: Text(
                        bName,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F2942)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  tr('app.nfsa_notice'),
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Voice Audio Assistant Toggle
        IconButton(
          tooltip: VoiceAssistantService.instance.isVoiceMuted
              ? 'आवाज़ चालू करें / Unmute Voice'
              : 'आवाज़ बंद करें / Mute Voice',
          icon: Icon(
            VoiceAssistantService.instance.isVoiceMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            size: 22,
            color: VoiceAssistantService.instance.isVoiceMuted
                ? const Color(0xFF94A3B8)
                : const Color(0xFF15803D),
          ),
          onPressed: () {
            setState(() {
              VoiceAssistantService.instance.toggleMute();
            });
          },
        ),
        // Elderly / Simple Mode Toggle
        IconButton(
          tooltip: VoiceAssistantService.instance.isElderlyMode
              ? 'सामान्य मोड / Standard Mode'
              : 'बुजुर्ग / आसान मोड / Elderly Mode',
          icon: Icon(
            VoiceAssistantService.instance.isElderlyMode
                ? Icons.elderly_rounded
                : Icons.accessibility_new_rounded,
            size: 22,
            color: VoiceAssistantService.instance.isElderlyMode
                ? const Color(0xFFD97706)
                : const Color(0xFF64748B),
          ),
          onPressed: () {
            setState(() {
              final newMode = !VoiceAssistantService.instance.isElderlyMode;
              VoiceAssistantService.instance.setElderlyMode(newMode);
              if (newMode) {
                VoiceAssistantService.instance.speakLocalized(
                  hiText: 'आसान मोड चालू हो गया है। बटन और अक्षर बड़े कर दिए गए हैं।',
                  knText: 'ಸರಳ ಮೋಡ್ ಸಕ್ರಿಯಗೊಂಡಿದೆ. ಬಟನ್‌ಗಳು ಮತ್ತು ಅಕ್ಷರಗಳು ದೊಡ್ಡದಾಗಿವೆ.',
                  enText: 'Simple Mode enabled. Large buttons and text are active.',
                );
              }
            });
          },
        ),
        // Language Selector inside App Bar
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: LanguageSelectorWidget(isCompact: true),
        ),
        const SizedBox(width: 4),
        // Profile Icon Button
        IconButton(
          tooltip: 'राशन कार्ड प्रोफ़ाइल / Profile',
          icon: const Icon(Icons.account_circle_rounded, size: 22, color: Color(0xFF0F2942)),
          onPressed: _showBeneficiaryProfileModal,
        ),
        IconButton(
          tooltip: tr('nav.refresh'),
          icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
          onPressed: _loadBeneficiaryData,
        ),
        IconButton(
          tooltip: tr('history.title'),
          icon: const Icon(Icons.history_rounded, size: 20, color: Color(0xFF64748B)),
          onPressed: _navigateToIntentHistory,
        ),
        IconButton(
          tooltip: tr('nav.logout'),
          icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFF64748B)),
          onPressed: () {
            VoiceAssistantService.instance.stopVoiceAssistantMode();
            _apiService.logout();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
              (route) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // 1. BENEFICIARY PROFILE CARD
  Widget _buildBeneficiaryProfileCard() {
    final b = _beneficiary!;
    final cardLabel = _entitlement?.cardLabel ?? 'Priority Household (PHH)';

    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppConstants.primaryNavy,
            child: Text(
              b.nameForDemo.isNotEmpty ? b.nameForDemo.substring(0, 1) : 'C',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        b.nameForDemo,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConstants.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryNavy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppConstants.cardBorder),
                      ),
                      child: Text(
                        tr('app.cycle_label'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(status: b.status, fontSize: 10),
                    Text(
                      '${tr('profile.card_type', params: {'type': b.pseudonymousBeneficiaryId})}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
                    ),
                    Text(
                      '• $cardLabel ($_eligibleMembersCount ${tr('profile.family_members')})',
                      style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1b. ELIGIBLE HOUSEHOLD MEMBERS SELECTOR CARD (5 kg statutory quota / person)
  Widget _buildHouseholdMembersSelectorCard() {
    final maxEntitlement = _eligibleMembersCount * 5.0;

    return Container(
      key: const ValueKey('card_household_members_selector'),
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppConstants.accentBlue.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined, color: AppConstants.accentBlue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    tr('members.title'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.primaryNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  tr('members.badge'),
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppConstants.accentBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr('members.subtitle'),
            style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
          ),
          const SizedBox(height: 14),

          // Read-only entitlement formula card (Government Statutory Quota - Fixed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('members.formula', params: {
                    'count': '$_eligibleMembersCount',
                    'max': maxEntitlement.toStringAsFixed(1),
                  }),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
                const SizedBox(height: 3),
                Text(
                  'Combined Quota: ${(maxEntitlement * 0.8).toStringAsFixed(1)} kg Rice + ${(maxEntitlement * 0.2).toStringAsFixed(1)} kg Wheat',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // 3. PLAN YOUR UPCOMING COLLECTION (Only shown if choice not yet submitted)
  Widget _buildPlanCollectionSection() {
    final homeFpsName = _beneficiary?.registeredFpsName ?? 'Malleshwaram Seva Kendra';
    final hasActiveIntents = _activeIntents.isNotEmpty;
    final hasCompletedDelivery = _deliveryRecords.any((r) => r.deliveryStatus == 'DELIVERY_CONFIRMED' || r.citizenConfirmedAt != null);
    final hasPlanLocked = _entitlement?.rationReceivedForCycle == true || _userSubmittedChoice || hasActiveIntents || hasCompletedDelivery;
    final isReceived = _entitlement?.rationReceivedForCycle == true || hasCompletedDelivery;
    final activeFpsName = _deliveryRecords.isNotEmpty
        ? (_deliveryRecords.first.intendedFpsName ?? _deliveryRecords.first.registeredFpsName ?? homeFpsName)
        : (_activeIntents.isNotEmpty ? _activeIntents.first.intendedFpsName : homeFpsName);

    if (hasPlanLocked || isReceived) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('service.plan_title'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppConstants.primaryNavy,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasPlanLocked
              ? 'Collection plan registered. Further modifications are locked for Cycle 2026-09.'
              : tr('service.plan_subtitle'),
          style: TextStyle(
            fontSize: 12,
            color: hasPlanLocked ? const Color(0xFF15803D) : AppConstants.textSecondary,
            fontWeight: hasPlanLocked ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: AppConstants.space12),

        // Official Fair Price Shop Collection Card
        _buildServiceChoiceCard(
          title: hasPlanLocked ? 'Collect at Fair Price Shop (Locked)' : tr('service.fps_choice_title'),
          icon: hasPlanLocked ? Icons.lock_outline_rounded : Icons.storefront_outlined,
          iconColor: hasPlanLocked ? const Color(0xFF15803D) : AppConstants.primaryNavy,
          iconBg: hasPlanLocked ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
          badgeText: hasPlanLocked ? '🔒 PLAN LOCKED FOR CYCLE' : tr('service.fps_choice_badge'),
          badgeColor: hasPlanLocked ? const Color(0xFF15803D) : AppConstants.accentBlue,
          description: hasPlanLocked
              ? 'Your collection plan has been recorded and locked in pre-dispatch logistics for $activeFpsName.'
              : tr('service.fps_choice_desc'),
          contextDetail: tr('service.fps_choice_detail', params: {'fpsName': activeFpsName ?? homeFpsName}),
          priceTag: tr('service.fps_choice_price'),
          buttonLabel: hasPlanLocked ? '📍 Track Location & Plan ($activeFpsName)' : tr('service.fps_choice_btn'),
          buttonIcon: hasPlanLocked ? Icons.map_rounded : Icons.store_rounded,
          isPrimary: !hasPlanLocked,
          onTap: () {
            if (hasPlanLocked) {
              _showFpsRouteTrackingModal(activeFpsName ?? homeFpsName);
            } else {
              _navigateToIntentSelection(initialMode: 'FPS_COLLECTION');
            }
          },
        ),
      ],
    );
  }

  void _showFpsRouteTrackingModal(String fpsName) {
    VoiceAssistantService.instance.guideLocation();

    final fps = _fpsList.where((f) => 
      f.name.toLowerCase() == fpsName.toLowerCase() || 
      f.fpsId.toLowerCase() == fpsName.toLowerCase() ||
      fpsName.contains(f.fpsId)
    ).firstOrNull ?? (_fpsList.isNotEmpty ? _fpsList.first : null);

    final homeLat = fps != null && fps.latitude != 0 ? fps.latitude - 0.0035 : 13.0031;
    final homeLon = fps != null && fps.longitude != 0 ? fps.longitude - 0.0028 : 77.5643;
    final householdLoc = LatLng(homeLat, homeLon);
    final fpsLoc = fps != null ? LatLng(fps.latitude, fps.longitude) : const LatLng(13.0066, 77.5671);
    final mid = LatLng(
      (householdLoc.latitude + fpsLoc.latitude) / 2 + 0.0008,
      (householdLoc.longitude + fpsLoc.longitude) / 2 - 0.0006,
    );
    final routePoints = [householdLoc, mid, fpsLoc];

    final isHindi = VoiceAssistantService.instance.isHindi;
    final isKannada = VoiceAssistantService.instance.isKannada;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF15803D), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fpsName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy), overflow: TextOverflow.ellipsis),
                              Text(isHindi ? 'आपकी राशन दुकान का स्थान' : isKannada ? 'ನಿಮ್ಮ ಪಡಿತರ ಅಂಗಡಿಯ ಸ್ಥಳ' : 'Your Ration Shop Location', style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive OpenStreetMap Canvas
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 230,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng((householdLoc.latitude + fpsLoc.latitude) / 2, (householdLoc.longitude + fpsLoc.longitude) / 2),
                          initialZoom: 13.5,
                          minZoom: 8.0,
                          maxZoom: 18.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'org.karnataka.pds_demandsync',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                strokeWidth: 4.5,
                                color: const Color(0xFF2563EB),
                                borderStrokeWidth: 2.0,
                                borderColor: Colors.white,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: householdLoc,
                                width: 95,
                                height: 50,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF15803D),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                      ),
                                      child: const Icon(Icons.home_rounded, color: Colors.white, size: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(isHindi ? 'मेरा घर' : isKannada ? 'ನನ್ನ ಮನೆ' : 'My Household', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                              Marker(
                                point: fpsLoc,
                                width: 110,
                                height: 50,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppConstants.primaryNavy,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                      ),
                                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppConstants.primaryNavy,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(fps?.fpsId ?? 'FPS-CENTER', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.gps_fixed_rounded, color: Color(0xFF60A5FA), size: 12),
                              SizedBox(width: 4),
                              Text(
                                isHindi ? 'जीपीएस मार्ग सक्रिय • पैदल दूरी: ~10 मिनट' : isKannada ? 'ಲೈವ್ ಜಿಪಿಎಸ್ ಮಾರ್ಗ ಸಕ್ರಿಯ • ನಡಿಗೆ: ~10 ನಿಮಿಷ' : 'Live GPS Route Active • Walking: ~10 mins',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Details & Quota Breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isHindi ? 'संग्रह स्थिति' : isKannada ? 'ಸಂಗ್ರಹ ಸ್ಥಿತಿ' : 'Collection Status', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(isHindi ? '🔒 योजना सुरक्षित / तैयार' : isKannada ? '🔒 ಯೋಜನೆ ಲಾಕ್ ಆಗಿದೆ / ಸಿದ್ಧ' : '🔒 PLAN LOCKED / READY FOR DISPATCH', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isHindi ? 'निर्धारित केंद्र' : isKannada ? 'ಗೊತ್ತುಪಡಿಸಿದ ಕೇಂದ್ರ' : 'Designated Center', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                        Text(fpsName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isHindi ? 'कुल हकदार राशन' : isKannada ? 'ಒಟ್ಟು ಅರ್ಹ ಪಡಿತರ' : 'Total Entitled Grain', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                        Text('${_remainingBalanceKg > 0 ? _remainingBalanceKg.toStringAsFixed(1) : "20.0"} kg (' + (isHindi ? '100% मुफ्त' : isKannada ? '100% ಉಚಿತ' : '100% Free') + ')', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isHindi ? 'मानचित्र विंडो बंद करें' : isKannada ? 'ನಕ್ಷೆ ಮುಚ್ಚಿ' : 'Close Map Window', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceChoiceCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required String contextDetail,
    required String priceTag,
    required String buttonLabel,
    required IconData buttonIcon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppConstants.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contextDetail,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  priceTag,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(buttonIcon, size: 15),
              label: Text(buttonLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary ? AppConstants.primaryNavy : const Color(0xFFB45309),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. CURRENT REQUEST / DELIVERY STATUS (Combined Single Order Card)
  Widget _buildCurrentDeliveryStatusSection() {
    final combinedOrders = _getCombinedDeliveryOrders();
    if (combinedOrders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('delivery.section_title'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppConstants.primaryNavy,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppConstants.space12),

        ...combinedOrders.map((order) {
          final statusKey = order.deliveryStatus;
          final isConfirmed = statusKey == 'DELIVERY_CONFIRMED';
          final isDispute = statusKey == 'DELIVERY_DISPUTE';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: AppConstants.cardSurface,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: isDispute ? AppConstants.dangerRed.withValues(alpha: 0.4) : AppConstants.cardBorder,
                width: isDispute ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Order Header & Consolidated Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: AppConstants.primaryNavy, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          tr('delivery.order_num', params: {'orderId': order.baseRequestId}),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppConstants.textPrimary),
                        ),
                      ],
                    ),
                    StatusBadge(status: statusKey),
                  ],
                ),
                const SizedBox(height: 12),

                // Single 5-Stage Delivery Timeline
                DeliveryTimeline(currentStatus: statusKey),
                const SizedBox(height: 14),

                // Active Request Expected Delivery Timer / Countdown Card
                _buildExpectedDeliveryTimerCard(order, statusKey),
                const SizedBox(height: 14),

                // Prominent Delivery Delayed Alert Card (Government Stock Shortage)
                if (order.isDelayed) ...[
                  Container(
                    key: const ValueKey('card_stock_delay_alert'),
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              tr('delay.banner_title'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                order.expectedDeliveryWindow ?? tr('delay.expected_window'),
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('delay.banner_desc'),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFFB45309)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tr('delay.no_resubmit_hint'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Combined Commodities & Delivery Details Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.cardBorder.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('delivery.authorized_commodities'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppConstants.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: order.deliveryMode == 'HOME_DELIVERY'
                                  ? AppConstants.accentAmber.withValues(alpha: 0.15)
                                  : AppConstants.accentBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.deliveryMode == 'HOME_DELIVERY'
                                  ? tr('delivery.mode_home')
                                  : tr('delivery.mode_fps'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: order.deliveryMode == 'HOME_DELIVERY'
                                    ? const Color(0xFFB45309)
                                    : AppConstants.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Itemized Commodity Lines
                      ...order.items.map((item) {
                        final qty = item.authorizedQuantityKg > 0 ? item.authorizedQuantityKg : item.requestedQuantityKg;
                        final isRice = item.commodity.toLowerCase() == 'rice';
                        final commName = isRice ? tr('commodity.rice') : tr('commodity.wheat');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(
                                isRice ? Icons.grass_rounded : Icons.grain_rounded,
                                size: 15,
                                color: isRice ? AppConstants.primaryNavy : const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '• ${qty.toStringAsFixed(1)} ${tr('commodity.kg')} $commName',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppConstants.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                tr('commodity.free_tag'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Delivery Destination & Logistics Fee Row
                      if (order.transportFeeInr > 0 || order.deliveryAddress != null || order.intendedFpsName != null) ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: AppConstants.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        tr('delivery.delivery_address', params: {'address': order.deliveryAddress!}),
                                        style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Expanded(
                                child: Text(
                                  tr('delivery.pickup_location', params: {'fpsName': order.intendedFpsName ?? order.registeredFpsName ?? "Assigned FPS"}),
                                  style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                                ),
                              ),
                            if (order.transportFeeInr > 0)
                              Text(
                                tr('delivery.logistics_fee', params: {'fee': order.transportFeeInr.toStringAsFixed(2)}),
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // If Dispute
                if (isDispute && order.disputeReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.report_problem_rounded, color: AppConstants.dangerRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('delivery.dispute_reason_banner', params: {'reason': order.disputeReason!}),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppConstants.dangerRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons if delivered but not confirmed/disputed
                if (!isConfirmed && !isDispute) ...[
                  const Divider(height: 20),
                  Text(
                    tr('delivery.did_you_receive'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmCombinedOrderReceipt(order),
                          icon: const Icon(Icons.check_circle_outline, size: 15),
                          label: Text(tr('delivery.btn_confirm_full'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.successGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCombinedDeliveryDisputeModal(order),
                          icon: const Icon(Icons.report_problem_outlined, size: 15),
                          label: Text(tr('delivery.btn_report_issue'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppConstants.dangerRed,
                            side: const BorderSide(color: AppConstants.dangerRed),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // Expected Delivery Timer / Reactive Countdown Card
  Widget _buildExpectedDeliveryTimerCard(CombinedCitizenDeliveryOrder order, String statusKey) {
    final isDelayed = order.isDelayed;
    final isOutForDelivery = statusKey == 'OUT_FOR_DELIVERY';
    final isCompleted = statusKey == 'DELIVERED' || statusKey == 'DELIVERY_CONFIRMED';

    // 1. Completed state: Delivered / Verified
    if (isCompleted) {
      return Container(
        key: const ValueKey('card_expected_delivery_timer'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('delivery.eta_label'),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D), letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tr('delivery.eta_completed'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '100% COMPLETE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Delayed state: Government Stock Shortage
    if (isDelayed) {
      final windowText = order.expectedDeliveryWindow ?? tr('delay.expected_window');
      return Container(
        key: const ValueKey('card_expected_delivery_timer'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_send_rounded, color: Color(0xFFB45309), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('delivery.eta_delayed_label'),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309), letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    windowText,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_clock, size: 12, color: Color(0xFFB45309)),
                  const SizedBox(width: 4),
                  Text(
                    tr('delay.badge'),
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 3. Active Delivery Countdown (Deterministic baseline target per order)
    final seed = order.baseRequestId.hashCode.abs();
    // Out for delivery is imminent (approx 1h 45m), Allocated/Requested is ~28h
    final totalDurationMinutes = isOutForDelivery ? (90 + (seed % 45)) : (1440 + (seed % 360));
    final createdAtParsed = order.items.isNotEmpty && order.items.first.createdAt.isNotEmpty
        ? DateTime.tryParse(order.items.first.createdAt) ?? _currentTime
        : _currentTime;

    final targetEta = createdAtParsed.add(Duration(minutes: totalDurationMinutes));
    final remainingDiff = targetEta.difference(_currentTime);
    final remainingSeconds = remainingDiff.inSeconds;

    String countdownDisplay;
    String statusNote;
    Color primaryColor;
    Color bgColor;
    Color borderColor;

    if (isOutForDelivery) {
      primaryColor = const Color(0xFF0284C7); // Vibrant Sky Blue
      bgColor = const Color(0xFFF0F9FF);
      borderColor = const Color(0xFFBAE6FD);
      statusNote = tr('delivery.eta_out_now');
    } else {
      primaryColor = AppConstants.primaryNavy;
      bgColor = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFCBD5E1);
      statusNote = remainingSeconds > 86400
          ? tr('delivery.eta_days_hours', params: {
              'days': '${remainingDiff.inDays}',
              'hours': '${remainingDiff.inHours % 24}',
            })
          : tr('delivery.eta_arriving_today');
    }

    if (remainingSeconds <= 0) {
      countdownDisplay = tr('delivery.eta_arriving_today');
    } else {
      final hours = (remainingSeconds ~/ 3600).toString().padLeft(2, '0');
      final minutes = ((remainingSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
      countdownDisplay = '$hours:$minutes:$seconds';
    }

    return Container(
      key: const ValueKey('card_expected_delivery_timer'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isOutForDelivery ? 1.5 : 1.0),
        boxShadow: isOutForDelivery
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOutForDelivery ? Icons.directions_bike_rounded : Icons.timer_outlined,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tr('delivery.eta_label').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (isOutForDelivery) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE TRACKING',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  statusNote,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (remainingSeconds > 0) ...[
                  const Icon(Icons.access_time_filled_rounded, size: 13, color: AppConstants.primaryNavy),
                  const SizedBox(width: 5),
                ],
                Text(
                  countdownDisplay,
                  key: const ValueKey('text_eta_countdown'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: isOutForDelivery ? const Color(0xFF0284C7) : AppConstants.primaryNavy,
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. RECENT DISTRIBUTION HISTORY (Compact List Rows)
  Widget _buildRecentDistributionHistorySection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('history.title'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryNavy,
                  letterSpacing: 0.5,
                ),
              ),
              TextButton(
                onPressed: _navigateToIntentHistory,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                child: Text(tr('history.view_timeline'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_activeIntents.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.backgroundLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppConstants.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('history.empty'),
                      style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ..._activeIntents.take(3).map((intent) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppConstants.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intent.intendedFpsName ?? intent.intendedFpsId,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${intent.commodity} • Mode: ${intent.deliveryMode.replaceAll('_', ' ')} • ${intent.intendedFpsId}',
                          style: const TextStyle(fontSize: 10.5, color: AppConstants.textSecondary),
                        ),
                      ],
                    ),
                    StatusBadge(status: intent.status, fontSize: 9.5),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
