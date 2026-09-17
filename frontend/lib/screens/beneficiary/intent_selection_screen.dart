import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import '../../services/voice_assistant_service.dart';
import 'intent_confirmation_screen.dart';

class IntentSelectionScreen extends StatefulWidget {
  final Beneficiary beneficiary;
  final ApiService? apiService;
  final String initialDeliveryMode;
  final int initialEligibleMembersCount;

  const IntentSelectionScreen({
    super.key,
    required this.beneficiary,
    this.apiService,
    this.initialDeliveryMode = 'FPS_COLLECTION',
    this.initialEligibleMembersCount = 5,
  });

  @override
  State<IntentSelectionScreen> createState() => _IntentSelectionScreenState();
}

class _IntentSelectionScreenState extends State<IntentSelectionScreen> {
  late final ApiService _apiService;
  List<FpsShop> _fpsList = [];
  FpsShop? _selectedFps;
  BeneficiaryEntitlementSummary? _entitlement;
  List<CitizenDeliveryRecord> _deliveryRecords = [];
  bool _isRationAlreadyReceived = false;
  bool _hasSpokenCycleReceivedMessage = false;
  bool _hasSpokenIntro = false;
  late String _deliveryMode;
  final TextEditingController _addressController = TextEditingController(
    text: '12th Cross, 4th Main, Malleshwaram, Bengaluru - 560003',
  );
  String _searchQuery = '';

  // Household Entitlement & Combined Allocation State
  late int _eligibleMembersCount;
  late double _riceQtyKg;
  late double _wheatQtyKg;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _deliveryMode = widget.initialDeliveryMode;
    _eligibleMembersCount = widget.initialEligibleMembersCount > 0 ? widget.initialEligibleMembersCount : 4;
    _riceQtyKg = _eligibleMembersCount * 4.0;
    _wheatQtyKg = _eligibleMembersCount * 1.0;
    _loadData();

    VoiceAssistantService.instance.onCommandRecognized = (cmd) {
      final text = cmd.toLowerCase();

      // Enforce cycle received check for ALL voice commands
      if (_isRationAlreadyReceived) {
        VoiceAssistantService.instance.guideCycleAlreadyReceived();
        return;
      }

      if (text.contains('ration') || text.contains('entitlement') || text.contains('quota') ||
          text.contains('राशन') || text.contains('हक') || text.contains('पात्रता') ||
          text.contains('ಪಡಿತರ') || text.contains('ಹಕ್ಕು') || text.contains('listen') || text.contains('सुनें') || text.contains('ಕೇಳಿ')) {
        VoiceAssistantService.instance.guideDemandEntitlement(
          totalKg: _maxHouseholdEntitlementKg,
          riceKg: _riceQtyKg,
          wheatKg: _wheatQtyKg,
          membersCount: _eligibleMembersCount,
        );
      } else if (text.contains('confirm') || text.contains('proceed') || text.contains('review') || text.contains('आगे') || text.contains('ಮುಂದುವರಿಯಿರಿ')) {
        if (_isOverEntitled || _errorMessage != null) {
          VoiceAssistantService.instance.guideStatutoryQuantityError();
          return;
        }
        _continueToReview();
      }
    };
  }

  double get _maxHouseholdEntitlementKg {
    if (_entitlement != null) {
      final entTotal = _entitlement!.statutoryEntitlementRiceKg + _entitlement!.statutoryEntitlementWheatKg;
      if (entTotal > 0) return entTotal;
    }
    return _eligibleMembersCount * 5.0;
  }
  double get _combinedQtyKg => _riceQtyKg + _wheatQtyKg;
  bool get _isOverEntitled => _combinedQtyKg > _maxHouseholdEntitlementKg;



  @override
  void dispose() {
    VoiceAssistantService.instance.onCommandRecognized = null;
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.fetchFpsList();

      BeneficiaryEntitlementSummary? ent;
      List<CitizenDeliveryRecord> deliveries = [];
      try {
        ent = await _apiService.fetchBeneficiaryEntitlementSummary(
          widget.beneficiary.pseudonymousBeneficiaryId,
          cycleId: '2026-09',
        );
      } catch (_) {}
      try {
        deliveries = await _apiService.fetchBeneficiaryDeliveryRecords(
          widget.beneficiary.pseudonymousBeneficiaryId,
          cycleId: '2026-09',
        );
      } catch (_) {}

      final hasCompletedDelivery = deliveries.any((r) => r.deliveryStatus == 'DELIVERY_CONFIRMED' || r.citizenConfirmedAt != null);
      final isAlreadyReceived = ent?.rationReceivedForCycle == true || hasCompletedDelivery;

      if (mounted) {
        setState(() {
          _fpsList = list;
          _entitlement = ent;
          _deliveryRecords = deliveries;
          _isRationAlreadyReceived = isAlreadyReceived;

          // Default to home registered shop
          _selectedFps = _fpsList.where((fps) => fps.fpsId == widget.beneficiary.registeredFpsId).firstOrNull ??
              (_fpsList.isNotEmpty ? _fpsList.first : null);

          // Sync member count authoritatively from government entitlement record.
          if (ent != null) {
            _eligibleMembersCount = ent.familyMembersCount > 0 ? ent.familyMembersCount : 1;
            _riceQtyKg = ent.statutoryEntitlementRiceKg;
            _wheatQtyKg = ent.statutoryEntitlementWheatKg;
            if (_riceQtyKg > 0 && _wheatQtyKg > 0) {
              _commodityOption = 'Both';
            } else if (_riceQtyKg > 0) {
              _commodityOption = 'Rice';
            } else {
              _commodityOption = 'Wheat';
            }
          }

          _isLoading = false;
        });

        // Priority State Handling:
        // State A: Ration already received -> speak immediately once
        if (isAlreadyReceived) {
          if (!_hasSpokenCycleReceivedMessage) {
            _hasSpokenCycleReceivedMessage = true;
            VoiceAssistantService.instance.guideCycleAlreadyReceived();
          }
        } else {
          // State B: Ration not yet received -> speak entitlement once
          if (!_hasSpokenIntro) {
            _hasSpokenIntro = true;
            VoiceAssistantService.instance.guideDemandEntitlement(
              totalKg: _riceQtyKg + _wheatQtyKg,
              riceKg: _riceQtyKg,
              wheatKg: _wheatQtyKg,
              membersCount: _eligibleMembersCount,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load Fair Price Shops & Entitlement: $e';
          _isLoading = false;
        });
      }
    }
  }

  double _getCalculatedDistance(FpsShop fps) {
    if (fps.fpsId == widget.beneficiary.registeredFpsId) {
      return 0.6; // Walking distance to home shop
    }
    final dLat = (fps.latitude - 12.9716).abs() * 111.0;
    final dLng = (fps.longitude - 77.5946).abs() * 105.0;
    final dist = sqrt(dLat * dLat + dLng * dLng) + 1.2;
    return double.parse(dist.toStringAsFixed(1));
  }

  double _calculateTransportFee(double distanceKm) {
    if (_deliveryMode != 'HOME_DELIVERY') return 0.0;
    const baseFee = 20.0;
    final extraKm = max(0.0, distanceKm - 2.0);
    return double.parse((baseFee + extraKm * 5.0).toStringAsFixed(2));
  }

  String _commodityOption = 'Both'; // 'Both', 'Rice', 'Wheat'

  void _continueToReview() async {
    if (_isRationAlreadyReceived) {
      VoiceAssistantService.instance.guideCycleAlreadyReceived();
      return;
    }
    if (_isOverEntitled || _errorMessage != null) {
      VoiceAssistantService.instance.guideStatutoryQuantityError();
      return;
    }
    if (_selectedFps == null) return;

    final distance = _getCalculatedDistance(_selectedFps!);
    final fee = _calculateTransportFee(distance);

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntentConfirmationScreen(
          beneficiary: widget.beneficiary,
          intendedFps: _selectedFps!,
          commodityOption: _commodityOption,
          apiService: _apiService,
          deliveryMode: _deliveryMode,
          deliveryAddress: _deliveryMode == 'HOME_DELIVERY' ? _addressController.text.trim() : null,
          deliveryDistanceKm: distance,
          transportFeeInr: fee,
          entitlementSummary: _entitlement,
          eligibleMembersCount: _eligibleMembersCount,
          customRiceKg: _riceQtyKg,
          customWheatKg: _wheatQtyKg,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDist = _selectedFps != null ? _getCalculatedDistance(_selectedFps!) : 0.6;
    final transportFee = _calculateTransportFee(selectedDist);

    final riceTotal = _entitlement?.statutoryEntitlementRiceKg ?? 0.0;
    final wheatTotal = _entitlement?.statutoryEntitlementWheatKg ?? 0.0;
    final totalMonthly = riceTotal + wheatTotal;

    final riceConsumed = _entitlement?.consumedRiceKg ?? 0.0;
    final wheatConsumed = _entitlement?.consumedWheatKg ?? 0.0;
    final totalConsumed = riceConsumed + wheatConsumed;

    final remainingBalance = _entitlement?.totalEligibleBalanceKg ?? totalMonthly;

    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('entitlement.family_title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F2942), letterSpacing: 0.2),
                ),
                Text(
                  tr('app.nfsa_notice'),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF15803D), size: 24),
                tooltip: 'आवाज़ में सुनें / Listen',
                onPressed: () {
                  if (_isRationAlreadyReceived) {
                    VoiceAssistantService.instance.guideCycleAlreadyReceived();
                  } else if (_isOverEntitled || _errorMessage != null) {
                    VoiceAssistantService.instance.guideStatutoryQuantityError();
                  } else {
                    VoiceAssistantService.instance.guideDemandEntitlement(
                      totalKg: totalMonthly,
                      riceKg: _riceQtyKg,
                      wheatKg: _wheatQtyKg,
                      membersCount: _eligibleMembersCount,
                    );
                  }
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LanguageSelectorWidget(isCompact: true),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5, color: AppConstants.primaryNavy),
                      SizedBox(height: 16),
                      Text('Loading Fair Price Shops and Entitlement...', style: TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.space20, vertical: AppConstants.space20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const VoiceAssistantBanner(),
                          const SizedBox(height: AppConstants.space12),
                          if (_isRationAlreadyReceived) _buildAlreadyReceivedCard(),
                          _buildCitizenStepper(),
                          const SizedBox(height: AppConstants.space16),
                          _buildEntitlementCard(totalMonthly, _riceQtyKg, _wheatQtyKg),
                          const SizedBox(height: AppConstants.space20),
                          _buildSection2FpsSelection(),
                          const SizedBox(height: AppConstants.space20),
                          _buildSection4EntitlementSummary(totalMonthly, totalConsumed, remainingBalance),
                          const SizedBox(height: AppConstants.space20),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppConstants.dangerRed, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_errorMessage!, style: const TextStyle(color: AppConstants.dangerRed, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppConstants.space16),
                          ],
                            Center(
                              child: Text(
                                tr('intent.policy_footer'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppConstants.space16),
                        ],
                      ),
                    ),
                  ),
                ),
          bottomNavigationBar: _isLoading
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppConstants.cardBorder)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: _buildPrimarySubmitButton(transportFee),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  Widget _buildAlreadyReceivedCard() {
    final isHindi = VoiceAssistantService.instance.isHindi;
    final isKannada = VoiceAssistantService.instance.isKannada;
    final isElderly = VoiceAssistantService.instance.isElderlyMode;

    final title = isHindi
        ? 'इस चक्र का आपका राशन पहले ही प्राप्त हो चुका है। आप इस चक्र में दोबारा राशन नहीं चुन सकते।'
        : isKannada
            ? 'ಈ ಚಕ್ರದ ನಿಮ್ಮ ಪಡಿತರವನ್ನು ಈಗಾಗಲೇ ಸ್ವೀಕರಿಸಲಾಗಿದೆ. ಈ ಚಕ್ರದಲ್ಲಿ ನೀವು ಮತ್ತೆ ಪಡಿತರವನ್ನು ಆಯ್ಕೆ ಮಾಡಲು ಸಾಧ್ಯವಿಲ್ಲ.'
            : 'Your ration for this cycle has already been received. You cannot select ration again in this cycle.';

    final subtitle = isHindi
        ? 'सितंबर 2026 चक्र के लिए राशन वितरित किया जा चुका है। अगला चक्र 1 तारीख को खुलेगा।'
        : isKannada
            ? 'ಸೆಪ್ಟೆಂಬರ್ 2026 ರ ಚಕ್ರಕ್ಕೆ ಪಡಿತರ ವಿತರಿಸಲಾಗಿದೆ. ಮುಂದಿನ ಚಕ್ರವು 1 ನೇ ತಾರೀಖಿನಂದು ತೆರೆಯುತ್ತದೆ.'
            : 'Ration has already been distributed and confirmed for this cycle. Next cycle opens on Day 1.';

    final confirmedDate = _entitlement?.receiptConfirmedAt ??
        (_deliveryRecords.where((r) => r.citizenConfirmedAt != null).firstOrNull?.citizenConfirmedAt);

    return Container(
      key: const ValueKey('card_cycle_already_received'),
      margin: const EdgeInsets.only(bottom: AppConstants.space16),
      padding: EdgeInsets.all(isElderly ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: const Color(0xFF16A34A), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isElderly ? 52 : 46,
            height: isElderly ? 52 : 46,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF15803D),
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isElderly ? 16.5 : 14.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF14532D),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isElderly ? 13 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF166534),
                  ),
                ),
                if (confirmedDate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      'Confirmed on: $confirmedDate',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('btn_replay_already_received_audio'),
            tooltip: isHindi ? 'आवाज़ दोबारा सुनें' : isKannada ? 'ಧ್ವನಿಯನ್ನು ಪುನರಾವರ್ತಿಸಿ' : 'Replay Voice Message',
            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF15803D), size: 30),
            onPressed: () => VoiceAssistantService.instance.guideCycleAlreadyReceived(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // ENTITLEMENT CARD: STATUTORY QUOTA DETERMINED FOR HOUSEHOLD
  // -------------------------------------------------------------
  Widget _buildEntitlementCard(double totalMonthly, double riceKg, double wheatKg) {
    final isElderly = VoiceAssistantService.instance.isElderlyMode;
    final cardType = _entitlement?.cardType ?? widget.beneficiary.schemeType ?? 'PHH';

    return Container(
      key: const ValueKey('section_entitlement_card'),
      padding: EdgeInsets.all(isElderly ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF15803D).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Icon, Title, Scheme Badge, and Audio Listen button
          Row(
            children: [
              const Text('🌾', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('entitlement.card_header'),
                  style: TextStyle(
                    fontSize: isElderly ? 16 : 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2942),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  '$cardType • ${tr('entitlement.free_gov_subsidy')}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('btn_speak_entitlement'),
                tooltip: 'Listen to Entitlement / आवाज़ में सुनें',
                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF15803D), size: 24),
                onPressed: () {
                  VoiceAssistantService.instance.guideDemandEntitlement(
                    totalKg: totalMonthly,
                    riceKg: riceKg,
                    wheatKg: wheatKg,
                    membersCount: _eligibleMembersCount,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Family Members Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  '${tr('entitlement.family_members_count')}: ',
                  style: TextStyle(
                    fontSize: isElderly ? 15 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                Text(
                  '$_eligibleMembersCount',
                  style: TextStyle(
                    fontSize: isElderly ? 18 : 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2942),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'RC: ${widget.beneficiary.pseudonymousBeneficiaryId}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Rice Entitlement Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const Text('🌾', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  tr('entitlement.rice_label'),
                  style: TextStyle(
                    fontSize: isElderly ? 17 : 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Text(
                  '${riceKg.toStringAsFixed(0)} kg',
                  style: TextStyle(
                    fontSize: isElderly ? 19 : 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F2942),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Wheat Entitlement Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const Text('🌾', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  tr('entitlement.wheat_label'),
                  style: TextStyle(
                    fontSize: isElderly ? 17 : 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Text(
                  '${wheatKg.toStringAsFixed(0)} kg',
                  style: TextStyle(
                    fontSize: isElderly ? 19 : 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F2942),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Divider before Total
          const Divider(height: 18, thickness: 1.5, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 6),

          // TOTAL Entitlement Row (Visually Prominent)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Text(
                  tr('entitlement.total_label'),
                  style: TextStyle(
                    fontSize: isElderly ? 20 : 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2942),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${totalMonthly.toStringAsFixed(0)} kg',
                  style: TextStyle(
                    fontSize: isElderly ? 30 : 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Eligible Quantity Notice Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('entitlement.eligible_notice'),
                    style: TextStyle(
                      fontSize: isElderly ? 13 : 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitizenStepper() {
    final steps = [
      {'num': '1', 'title': tr('intent.step_fps'), 'active': true},
      {'num': '2', 'title': tr('intent.step_review'), 'active': true},
      {'num': '3', 'title': tr('intent.step_confirm'), 'active': false},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16, vertical: AppConstants.space12),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final isFirst = idx == 0;
            final isSecond = idx == 1;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isFirst || isSecond ? AppConstants.primaryNavy : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      step['num'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isFirst || isSecond ? Colors.white : AppConstants.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  step['title'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isFirst || isSecond ? FontWeight.w800 : FontWeight.w500,
                    color: isFirst || isSecond ? AppConstants.primaryNavy : AppConstants.textSecondary,
                  ),
                ),
                if (idx < steps.length - 1) ...[
                  Container(
                    width: 16,
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: isFirst ? AppConstants.primaryNavy : const Color(0xFFE2E8F0),
                  ),
                ],
              ],
            );
          }).toList(),
        ),
      ),
    );
  }



  // SECTION 2: CHOOSE YOUR INTENDED FAIR PRICE SHOP
  Widget _buildSection2FpsSelection() {
    final homeFpsId = widget.beneficiary.registeredFpsId;

    // Filter list based on search query
    final filteredFps = _fpsList.where((fps) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return fps.name.toLowerCase().contains(q) || fps.fpsId.toLowerCase().contains(q);
    }).toList();

    // Ensure home shop is sorted first
    filteredFps.sort((a, b) {
      if (a.fpsId == homeFpsId) return -1;
      if (b.fpsId == homeFpsId) return 1;
      return a.name.compareTo(b.name);
    });

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
                tr('intent.section2_title'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryNavy,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_fpsList.length} Active Centers',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppConstants.accentBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: tr('intent.fps_search_hint'),
              hintStyle: const TextStyle(fontSize: 12, color: AppConstants.textTertiary),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppConstants.textSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppConstants.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppConstants.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppConstants.accentBlue, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          // FPS Cards List
          ...filteredFps.map((fps) {
            final isSelected = _selectedFps?.fpsId == fps.fpsId;
            final isHome = fps.fpsId == homeFpsId;
            final dist = _getCalculatedDistance(fps);

            return InkWell(
              onTap: _isRationAlreadyReceived
                  ? () => VoiceAssistantService.instance.guideCycleAlreadyReceived()
                  : () {
                      setState(() => _selectedFps = fps);
                      VoiceAssistantService.instance.guideShopSelected(fps.name);
                    },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppConstants.accentBlue : (isHome ? AppConstants.accentBlue.withValues(alpha: 0.3) : AppConstants.cardBorder),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppConstants.accentBlue : AppConstants.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fps.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                    color: AppConstants.primaryNavy,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isHome) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryNavy,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(tr('intent.home_fps_tag'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: const Color(0xFFE9D5FF)),
                                  ),
                                  child: Text(tr('intent.portability_tag'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF7E22CE))),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${fps.fpsId} • Distance: ${dist.toStringAsFixed(1)} km • Storage: ${(fps.capacityKg / 1000).toStringAsFixed(0)} MT',
                            style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: AppConstants.accentBlue),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  '${fps.district} • GPS: ${fps.latitude.toStringAsFixed(4)}° N, ${fps.longitude.toStringAsFixed(4)}° E',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppConstants.accentBlue),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _showFpsMapLocationModal(fps, dist),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppConstants.accentBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map_rounded, size: 13, color: AppConstants.accentBlue),
                                    SizedBox(width: 4),
                                    Text(
                                      'Track & View Exact Location Details',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppConstants.accentBlue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusBadge(status: fps.currentInventoryTotalKg > 1000 ? 'ACTIVE' : 'WARNING', fontSize: 9.5),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  LatLng _getHouseholdLocation() {
    final home = _fpsList.where((f) => f.fpsId == widget.beneficiary.registeredFpsId).firstOrNull ?? _selectedFps ?? (_fpsList.isNotEmpty ? _fpsList.first : null);
    if (home != null && home.latitude != 0 && home.longitude != 0) {
      return LatLng(home.latitude - 0.0035, home.longitude - 0.0028);
    }
    return const LatLng(13.0031, 77.5643);
  }

  List<LatLng> _getRouteToFps(FpsShop fps) {
    final home = _getHouseholdLocation();
    final shop = LatLng(fps.latitude, fps.longitude);
    final mid = LatLng(
      (home.latitude + shop.latitude) / 2 + 0.0008,
      (home.longitude + shop.longitude) / 2 - 0.0006,
    );
    return [home, mid, shop];
  }

  void _showFpsMapLocationModal(FpsShop fps, double distanceKm) {
    VoiceAssistantService.instance.guideLocation();

    final householdLoc = _getHouseholdLocation();
    final fpsLoc = LatLng(fps.latitude, fps.longitude);
    final routePoints = _getRouteToFps(fps);
    final midLat = (householdLoc.latitude + fpsLoc.latitude) / 2;
    final midLon = (householdLoc.longitude + fpsLoc.longitude) / 2;

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
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.storefront_rounded, color: AppConstants.accentBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fps.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy), overflow: TextOverflow.ellipsis),
                              Text((isHindi ? 'आपकी राशन दुकान • केंद्र कोड: ' : isKannada ? 'ನಿಮ್ಮ ಪಡಿತರ ಅಂಗಡಿ • ಕೇಂದ್ರ ಕೋಡ್: ' : 'Your Ration Shop • Center Code: ') + fps.fpsId, style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary)),
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

              // 1. Real OpenStreetMap Route Tracking Canvas
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
                          initialCenter: LatLng(midLat, midLon),
                          initialZoom: 13.0,
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
                              // Household Marker
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
                              // FPS Marker
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
                                      child: Text(fps.fpsId, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Overlay Telemetry
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
                              const Icon(Icons.navigation_rounded, color: Color(0xFF60A5FA), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                (isHindi ? 'दूरी: ' : isKannada ? 'ದೂರ: ' : 'Distance: ') + '${distanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
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

              _buildLocationDetailRow(Icons.place_rounded, isHindi ? 'जिला और क्षेत्र' : isKannada ? 'ಜಿಲ್ಲೆ ಮತ್ತು ಪ್ರದೇಶ' : 'District & Area', '${fps.district}, Karnataka'),
              const SizedBox(height: 8),
              _buildLocationDetailRow(Icons.gps_fixed_rounded, isHindi ? 'जीपीएस स्थान' : isKannada ? 'ಜಿಪಿಎಸ್ ನಿರ್ದೇಶಾಂಕಗಳು' : 'Precise GPS Coordinates', '${fps.latitude.toStringAsFixed(6)}° N, ${fps.longitude.toStringAsFixed(6)}° E'),
              const SizedBox(height: 8),
              _buildLocationDetailRow(Icons.directions_walk_rounded, isHindi ? 'घर से दूरी' : isKannada ? 'ಮನೆಯಿಂದ ದೂರ' : 'Distance from Household', '${distanceKm.toStringAsFixed(1)} km'),
              const SizedBox(height: 8),
              _buildLocationDetailRow(Icons.warehouse_rounded, isHindi ? 'भंडारण क्षमता' : isKannada ? 'ದಾಸ್ತಾನು ಸಾಮರ್ಥ್ಯ' : 'Storage Capacity & Stock', '${(fps.capacityKg / 1000).toStringAsFixed(0)} MT'),
              const SizedBox(height: 18),

              // Action CTA: Select and Lock this Fair Price Shop
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _selectedFps = fps);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📍 Selected ${fps.name} (${fps.fpsId}) as your collection Fair Price Shop.'),
                      backgroundColor: const Color(0xFF15803D),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: Text(isHindi ? '✓ इस राशन दुकान को चुनें' : isKannada ? '✓ ಈ ಪಡಿತರ ಅಂಗಡಿಯನ್ನು ಆಯ್ಕೆಮಾಡಿ' : '✓ Select This Fair Price Shop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppConstants.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
            ],
          ),
        ),
      ],
    );
  }



  // SECTION 4: STATUTORY QUOTA SUMMARY (Government Approved)
  Widget _buildSection4EntitlementSummary(double monthly, double consumed, double remaining) {
    final riceTotal = _eligibleMembersCount * 4.0;
    final wheatTotal = _eligibleMembersCount * 1.0;

    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('intent.section4_title'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryNavy,
                  letterSpacing: 0.5,
                ),
              ),
              const Text(
                'STATUTORY QUOTA',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final b1 = _buildEntitlementBox(tr('entitlement.monthly_quota'), '${monthly.toStringAsFixed(1)} ${tr('commodity.kg')}', '100% Subsidized', isHighlight: true);
              final b2 = _buildEntitlementBox(tr('commodity.rice'), '${riceTotal.toStringAsFixed(1)} ${tr('commodity.kg')}', '₹0.00 / kg');
              final b3 = _buildEntitlementBox(tr('commodity.wheat'), '${wheatTotal.toStringAsFixed(1)} ${tr('commodity.kg')}', '₹0.00 / kg');
              final b4 = _buildEntitlementBox('Planning Cycle', 'Cycle 2026-10', 'Statewide PDS');

              if (isNarrow) {
                return Column(
                  children: [
                    Row(children: [Expanded(child: b1), const SizedBox(width: 8), Expanded(child: b2)]),
                    const SizedBox(height: 8),
                    Row(children: [Expanded(child: b3), const SizedBox(width: 8), Expanded(child: b4)]),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(child: b1),
                    const SizedBox(width: 8),
                    Expanded(child: b2),
                    const SizedBox(width: 8),
                    Expanded(child: b3),
                    const SizedBox(width: 8),
                    Expanded(child: b4),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEntitlementBox(String label, String value, String sub, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isHighlight ? AppConstants.primaryNavy : AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHighlight ? AppConstants.primaryNavy : AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isHighlight ? Colors.white70 : AppConstants.textSecondary, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isHighlight ? Colors.white : AppConstants.textPrimary),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: TextStyle(fontSize: 9, color: isHighlight ? Colors.white70 : AppConstants.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }



  // CTA: SUBMIT BUTTON
  Widget _buildPrimarySubmitButton(double transportFee) {
    final isReceived = _isRationAlreadyReceived;
    final isReady = _selectedFps != null && !_isOverEntitled && !isReceived && _errorMessage == null;
    final isHindi = VoiceAssistantService.instance.isHindi;
    final isKannada = VoiceAssistantService.instance.isKannada;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isReceived) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 18, color: Color(0xFFB91C1C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHindi
                        ? 'इस चक्र का आपका राशन पहले ही प्राप्त हो चुका है। आप इस चक्र में दोबारा राशन नहीं चुन सकते।'
                        : isKannada
                            ? 'ಈ ಚಕ್ರದ ನಿಮ್ಮ ಪಡಿತರವನ್ನು ಈಗಾಗಲೇ ಸ್ವೀಕರಿಸಲಾಗಿದೆ. ಈ ಚಕ್ರದಲ್ಲಿ ನೀವು ಮತ್ತೆ ಪಡಿತರವನ್ನು ಆಯ್ಕೆ ಮಾಡಲು ಸಾಧ್ಯವಿಲ್ಲ.'
                            : 'Your ration for this cycle has already been received. You cannot select ration again in this cycle.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7F1D1D)),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_isOverEntitled) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              isHindi
                  ? 'चुनी गई मात्रा अनुमत मासिक सीमा से अधिक है।'
                  : isKannada
                      ? 'ಆಯ್ಕೆಮಾಡಿದ ಪ್ರಮಾಣವು ಅನುಮತಿಸಲಾದ ಮಾಸಿಕ ಮಿತಿಯನ್ನು ಮೀರಿದೆ.'
                      : 'Selected quantity exceeds statutory monthly entitlement ceiling.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.dangerRed),
            ),
          ),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const ValueKey('btn_continue_to_review'),
            onPressed: isReady
                ? _continueToReview
                : (isReceived ? () => VoiceAssistantService.instance.guideCycleAlreadyReceived() : null),
            icon: Icon(isReceived ? Icons.lock_outline_rounded : Icons.arrow_forward_rounded, size: 18),
            label: Text(
              isReceived
                  ? (isHindi
                      ? 'राशन प्राप्त हो चुका है • नया चयन अक्षम'
                      : isKannada
                          ? 'ಪಡಿತರ ಸ್ವೀಕರಿಸಲಾಗಿದೆ • ಹೊಸ ಆಯ್ಕೆ ಇಲ್ಲ'
                          : 'Already Received • No New Selection in This Cycle')
                  : (_deliveryMode == 'HOME_DELIVERY'
                      ? tr('intent.btn_continue_home', params: {'fee': transportFee.toStringAsFixed(2)})
                      : tr('intent.btn_continue_fps')),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReady ? AppConstants.primaryNavy : Colors.grey.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }
}
