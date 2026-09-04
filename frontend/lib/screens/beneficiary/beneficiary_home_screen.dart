import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/delivery_timeline.dart';
import 'biometric_verification_dialog.dart';
import 'intent_selection_screen.dart';
import 'intent_history_screen.dart';
import 'demo_login_screen.dart';

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

  // Household-based Entitlement State (5 kg / eligible person)
  int _eligibleMembersCount = 5;
  double _distributedQuantityKg = 0.0;
  double _remainingBalanceKg = 25.0;
  bool _isBiometricVerified = false;

  // Active Request ETA Countdown State
  Timer? _etaCountdownTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadBeneficiaryData();
  }

  @override
  void dispose() {
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
          _planningCycleState = cycleState;
          if (ent.familyMembersCount > 0) {
            _eligibleMembersCount = ent.familyMembersCount;
          }
          _remainingBalanceKg = (_eligibleMembersCount * 5.0 - _distributedQuantityKg).clamp(0.0, _eligibleMembersCount * 5.0);
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

    // Enforce PDS Business Rule: Once ration is received and confirmed for current cycle, no new request allowed
    if (_entitlement?.rationReceivedForCycle == true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppConstants.successGreen, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('delivery.ration_received_badge'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('delivery.ration_received_desc'),
                style: const TextStyle(fontSize: 13, color: AppConstants.textPrimary, height: 1.4),
              ),
              if (_entitlement?.receiptConfirmedAt != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Confirmed on: ${_entitlement!.receiptConfirmedAt!}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('nav.close'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final isOpen = _planningCycleState?['is_open'] ?? true;
    final planningDay = _planningCycleState?['planning_day'] ?? 22;
    if (!isOpen || planningDay >= 25) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: Color(0xFFB91C1C), size: 24),
              const SizedBox(width: 8),
              Text(
                tr('cycle.window_closed'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('cycle.locked_cannot_edit', params: {'cycle': _planningCycleState?['cycle_id'] ?? '2026-09'}),
                style: const TextStyle(fontSize: 13, color: AppConstants.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFB91C1C)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Day $planningDay: Demand baseline snapshot is permanently sealed into district pre-dispatch logistics.',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('nav.close'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

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

    if (result == true || result == null) {
      _loadBeneficiaryData();
    }
  }

  void _openBiometricVerificationDialog(CombinedCitizenDeliveryOrder order) async {
    if (_beneficiary == null) return;

    final riceQty = order.authorizedRiceKg > 0 ? order.authorizedRiceKg : (_eligibleMembersCount * 4.0);
    final wheatQty = order.authorizedWheatKg > 0 ? order.authorizedWheatKg : (_eligibleMembersCount * 1.0);

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BiometricVerificationDialog(
        beneficiary: _beneficiary!,
        entitlement: _entitlement,
        deliveryMode: order.deliveryMode,
        deliveryAddress: order.deliveryAddress,
        fpsName: order.intendedFpsName ?? order.registeredFpsName,
        riceQtyKg: riceQty,
        wheatQtyKg: wheatQty,
        eligibleMembersCount: _eligibleMembersCount,
        onDistributionComplete: (distributedKg, remainingKg) {
          setState(() {
            _distributedQuantityKg = distributedKg;
            _remainingBalanceKg = remainingKg;
            _isBiometricVerified = true;
          });
        },
      ),
    );

    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('biometric.distribute_success_toast')),
          backgroundColor: const Color(0xFF15803D),
          duration: const Duration(seconds: 4),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppConstants.backgroundLight,
          appBar: _buildGovernmentAppBar(),
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
                                // 0. Prominent Language Selector Bar
                                _buildLanguageSelectorQuickBar(),
                                const SizedBox(height: AppConstants.space16),

                                // 0b. Authoritative Planning Cycle & Choice Window Visualizer
                                _buildPlanningCycleBanner(),
                                const SizedBox(height: AppConstants.space16),

                                // 1. Beneficiary Profile & Card Identity Card
                                _buildBeneficiaryProfileCard(),
                                const SizedBox(height: AppConstants.space16),

                                // 1b. Eligible Household Members Selector (5 kg per person)
                                _buildHouseholdMembersSelectorCard(),
                                const SizedBox(height: AppConstants.space16),

                                // 2. HERO: Your Ration Entitlement (Progress visualization & remaining dominant)
                                _buildHeroRationEntitlementCard(),
                                const SizedBox(height: AppConstants.space20),

                                // 3. Plan Your Upcoming Collection (Two Large Service Cards)
                                _buildPlanCollectionSection(),
                                const SizedBox(height: AppConstants.space20),

                                // 4. Current Request / Delivery Status (5-Stage Timeline)
                                if (_deliveryRecords.isNotEmpty) ...[
                                  _buildCurrentDeliveryStatusSection(),
                                  const SizedBox(height: AppConstants.space20),
                                ],

                                // 5. Recent Distribution History (Compact list rows)
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

  // LANGUAGE SELECTOR QUICK BAR
  Widget _buildLanguageSelectorQuickBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.language_rounded, size: 18, color: AppConstants.primaryNavy),
              const SizedBox(width: 8),
              Text(
                tr('lang.selector_title'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.primaryNavy,
                ),
              ),
            ],
          ),
          const LanguageSelectorWidget(
            isCompact: false,
            backgroundColor: Color(0xFFF1F5F9),
          ),
        ],
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
        color: isOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isOpen ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
          width: 1.2,
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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOpen ? Icons.event_available_rounded : Icons.lock_clock_rounded,
                    size: 18,
                    color: isOpen ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('cycle.timeline_title'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isOpen ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOpen ? tr('cycle.window_open') : tr('cycle.locked_badge'),
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
    return AppBar(
      backgroundColor: AppConstants.primaryNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tr('app.name')} • ${tr('app.dashboard')}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tr('app.nfsa_notice'),
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Language Selector inside App Bar
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: LanguageSelectorWidget(isCompact: true),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: tr('nav.refresh'),
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: _loadBeneficiaryData,
        ),
        IconButton(
          tooltip: tr('history.title'),
          icon: const Icon(Icons.history_rounded, size: 20),
          onPressed: _navigateToIntentHistory,
        ),
        IconButton(
          tooltip: tr('nav.logout'),
          icon: const Icon(Icons.logout_rounded, size: 20),
          onPressed: () {
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
                    Text(
                      b.nameForDemo,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppConstants.textPrimary),
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

          // Stepper & Live Formula Row
          Row(
            children: [
              // Interactive Stepper
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppConstants.cardBorder),
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('btn_decrement_members'),
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      onPressed: _eligibleMembersCount > 1
                          ? () {
                              setState(() {
                                _eligibleMembersCount--;
                                _remainingBalanceKg = (_eligibleMembersCount * 5.0 - _distributedQuantityKg).clamp(0.0, _eligibleMembersCount * 5.0);
                              });
                            }
                          : null,
                      tooltip: 'Decrease eligible members',
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        '$_eligibleMembersCount',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('btn_increment_members'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: _eligibleMembersCount < 8
                          ? () {
                              setState(() {
                                _eligibleMembersCount++;
                                _remainingBalanceKg = (_eligibleMembersCount * 5.0 - _distributedQuantityKg).clamp(0.0, _eligibleMembersCount * 5.0);
                              });
                            }
                          : null,
                      tooltip: 'Increase eligible members',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Live Calculation Pill
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Combined Quota: ${(maxEntitlement * 0.8).toStringAsFixed(1)} kg Rice + ${(maxEntitlement * 0.2).toStringAsFixed(1)} kg Wheat',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. HERO: YOUR RATION ENTITLEMENT CARD
  Widget _buildHeroRationEntitlementCard() {
    final totalEntitlementKg = _eligibleMembersCount * 5.0;
    final riceTotal = _eligibleMembersCount * 4.0;
    final wheatTotal = _eligibleMembersCount * 1.0;

    final totalConsumedKg = _distributedQuantityKg;
    final riceConsumed = (_distributedQuantityKg * 0.8).clamp(0.0, riceTotal);
    final wheatConsumed = (_distributedQuantityKg * 0.2).clamp(0.0, wheatTotal);

    final riceRemaining = (riceTotal - riceConsumed).clamp(0.0, riceTotal);
    final wheatRemaining = (wheatTotal - wheatConsumed).clamp(0.0, wheatTotal);
    final remainingBalanceKg = _remainingBalanceKg;

    final double progressFraction = totalEntitlementKg > 0
        ? (totalConsumedKg / totalEntitlementKg).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppConstants.space20),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppConstants.accentBlue.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Free Subsidized Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_turned_in_outlined, color: AppConstants.accentBlue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    tr('entitlement.title'),
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
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  tr('commodity.entitled_free'),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space16),

          // Main Hero Highlight: Remaining Entitlement (Visually Dominant)
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: AppConstants.primaryNavy,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('entitlement.remaining_balance').toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            remainingBalanceKg.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr('commodity.kg').toUpperCase(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tr('commodity.rice')}: ${riceRemaining.toStringAsFixed(1)} ${tr('commodity.kg')}  •  ${tr('commodity.wheat')}: ${wheatRemaining.toStringAsFixed(1)} ${tr('commodity.kg')}',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(tr('entitlement.monthly_quota'), style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                      const SizedBox(height: 2),
                      Text(
                        '${totalEntitlementKg.toStringAsFixed(1)} ${tr('commodity.kg')}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tr('entitlement.consumed')}: ${totalConsumedKg.toStringAsFixed(1)} ${tr('commodity.kg')}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFFFDE68A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.space16),

          // Progress Bar Visualization
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progressFraction * 100).toStringAsFixed(0)}% Lifted',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                  ),
                  Text(
                    '${remainingBalanceKg.toStringAsFixed(1)} ${tr('commodity.kg')} remaining',
                    style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 8,
                  backgroundColor: AppConstants.primaryNavy.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressFraction > 0.8
                        ? AppConstants.successGreen
                        : (progressFraction > 0.4 ? AppConstants.accentAmber : AppConstants.accentBlue),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Dynamic Lifecycle Status Summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        tr('biometric.summary_entitlement', params: {'max': totalEntitlementKg.toStringAsFixed(1)}),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
                      ),
                      Container(margin: const EdgeInsets.symmetric(horizontal: 8), width: 1, height: 12, color: Colors.grey.shade300),
                      Text(
                        tr('biometric.summary_distributed', params: {'dist': totalConsumedKg.toStringAsFixed(1)}),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                      ),
                      Container(margin: const EdgeInsets.symmetric(horizontal: 8), width: 1, height: 12, color: Colors.grey.shade300),
                      Text(
                        tr('biometric.summary_remaining', params: {'rem': remainingBalanceKg.toStringAsFixed(1)}),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Policy rule statement
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: AppConstants.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr('entitlement.statutory_rule'),
                  style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. PLAN YOUR UPCOMING COLLECTION (Two Large Service Cards)
  Widget _buildPlanCollectionSection() {
    final homeFpsName = _beneficiary?.registeredFpsName ?? 'Malleshwaram Seva Kendra';
    final isReceived = _entitlement?.rationReceivedForCycle == true;

    if (isReceived) {
      return Container(
        key: const ValueKey('card_ration_received_cycle_lock'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF166534)),
                      const SizedBox(width: 6),
                      Text(
                        tr('delivery.ration_received_badge'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _planningCycleState?['cycle_id'] ?? '2026-09',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr('delivery.ration_received_desc'),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppConstants.textPrimary,
                height: 1.45,
              ),
            ),
            if (_entitlement?.receiptConfirmedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Receipt Confirmed: ${_entitlement!.receiptConfirmedAt}',
                style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 15, color: AppConstants.textSecondary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ration application controls are closed for this cycle. You can submit a new request when the next distribution cycle begins.',
                      style: TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
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
          tr('service.plan_subtitle'),
          style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: AppConstants.space12),

        // Two Large Service Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 580;

            final card1 = _buildServiceChoiceCard(
              title: tr('service.fps_choice_title'),
              icon: Icons.storefront_outlined,
              iconColor: AppConstants.primaryNavy,
              iconBg: const Color(0xFFEFF6FF),
              badgeText: tr('service.fps_choice_badge'),
              badgeColor: AppConstants.accentBlue,
              description: tr('service.fps_choice_desc'),
              contextDetail: tr('service.fps_choice_detail', params: {'fpsName': homeFpsName}),
              priceTag: tr('service.fps_choice_price'),
              buttonLabel: tr('service.fps_choice_btn'),
              buttonIcon: Icons.store_rounded,
              isPrimary: true,
              onTap: () => _navigateToIntentSelection(initialMode: 'FPS_COLLECTION'),
            );

            final card2 = _buildServiceChoiceCard(
              title: tr('service.home_choice_title'),
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFFD97706),
              iconBg: const Color(0xFFFEF3C7),
              badgeText: tr('service.home_choice_badge'),
              badgeColor: const Color(0xFFD97706),
              description: tr('service.home_choice_desc'),
              contextDetail: tr('service.home_choice_detail'),
              priceTag: tr('service.home_choice_price'),
              buttonLabel: tr('service.home_choice_btn'),
              buttonIcon: Icons.electric_moped_outlined,
              isPrimary: false,
              onTap: () => _navigateToIntentSelection(initialMode: 'HOME_DELIVERY'),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 14),
                  Expanded(child: card2),
                ],
              );
            } else {
              return Column(
                children: [
                  card1,
                  const SizedBox(height: 12),
                  card2,
                ],
              );
            }
          },
        ),
      ],
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

                // Biometric Handover & Distribution Verification Card
                _buildBiometricVerificationTriggerCard(order),

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

  Widget _buildBiometricVerificationTriggerCard(CombinedCitizenDeliveryOrder order) {
    final isHome = order.deliveryMode == 'HOME_DELIVERY';

    return Container(
      key: const ValueKey('card_biometric_verification_trigger'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isBiometricVerified ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isBiometricVerified ? const Color(0xFF86EFAC) : AppConstants.accentBlue.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isBiometricVerified ? Icons.verified_user_rounded : Icons.fingerprint_rounded,
                    color: _isBiometricVerified ? const Color(0xFF15803D) : AppConstants.accentBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isBiometricVerified
                        ? tr('biometric.distributed_badge')
                        : (isHome ? 'DOORSTEP BIOMETRIC VERIFICATION' : 'FPS COUNTER BIOMETRIC VERIFICATION'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _isBiometricVerified ? const Color(0xFF15803D) : AppConstants.primaryNavy,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _isBiometricVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isBiometricVerified ? 'HANDOVER COMPLETE' : 'VERIFICATION REQUIRED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _isBiometricVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isBiometricVerified
                ? 'Identity verified via simulated biometric ePoS terminal. Foodgrain successfully handed over and quota deducted.'
                : (isHome ? tr('biometric.doorstep_banner') : tr('biometric.fps_banner')),
            style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 10),

          if (!_isBiometricVerified)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_start_biometric_verification'),
                onPressed: () => _openBiometricVerificationDialog(order),
                icon: const Icon(Icons.fingerprint_rounded, size: 16),
                label: Text(
                  isHome ? tr('biometric.btn_verify_home') : tr('biometric.btn_verify_fps'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
        ],
      ),
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
