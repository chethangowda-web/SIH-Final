import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/delivery_timeline.dart';
import '../../widgets/voice_pictorial_assist.dart';
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
          backgroundColor: const Color(0xFFF0F4F8),
          appBar: _buildGovernmentAppBar(),
          body: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2.5, color: AppConstants.primaryNavy),
                      const SizedBox(height: 16),
                      Text(tr('beneficiary.home.loading'), style: const TextStyle(color: AppConstants.textSecondary, fontSize: 14)),
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
                            Icon(Icons.signal_wifi_off_rounded, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              tr('beneficiary.home.network_error'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, color: AppConstants.textPrimary, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _loadBeneficiaryData,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(tr('beneficiary.home.retry'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBeneficiaryData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: _buildSimpleBody(),
                          ),
                        ),
                      ),
                    ),
        );
      },
    );
  }

  /// Simple voice-first 4-tile beneficiary home body.
  Widget _buildSimpleBody() {
    final name = _beneficiary?.nameForDemo ?? '';
    final riceKg = _entitlement?.statutoryEntitlementRiceKg;
    final wheatKg = _entitlement?.statutoryEntitlementWheatKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── AI Voice Greeting Banner ──────────────────────────────────────
        _buildAiGreetingBanner(name),
        const SizedBox(height: 16),

        // ── Monthly Ration Entitlement Card ──────────────────────────────
        _buildSimpleEntitlementCard(riceKg, wheatKg),
        const SizedBox(height: 20),

        // ── 4 Action Tiles ────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.05,
          children: [
            _buildActionTile(emoji: '🌾', label: tr('beneficiary.home.action_need'), color: const Color(0xFF1A3D6B), id: 'tile_what_do_i_need', onTap: () => _navigateToIntentSelection()),
            _buildActionTile(emoji: '🏪', label: tr('beneficiary.home.action_shop'), color: const Color(0xFF065F46), id: 'tile_my_shop', onTap: () => _showShopSheet()),
            _buildActionTile(emoji: '🚚', label: tr('beneficiary.home.action_track'), color: const Color(0xFF7C3AED), id: 'tile_track', onTap: () => _showTrackSheet()),
            _buildActionTile(emoji: '🆘', label: tr('beneficiary.home.action_help'), color: const Color(0xFFB91C1C), id: 'tile_help', onTap: () => _showHelpSheet()),
          ],
        ),
        const SizedBox(height: 20),

        // ── Statutory footer ──────────────────────────────────────────────
        Center(
          child: Text(
            '${tr('app.gov_badge')} • ${tr('commodity.entitled_free')}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAiGreetingBanner(String name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3D6B), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1A3D6B).withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  tr('beneficiary.home.ai_greeting_short'),
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.88), height: 1.35),
                ),
              ],
            ),
          ),
          // Language selector in banner
          const LanguageSelectorWidget(isCompact: true),
        ],
      ),
    );
  }

  Widget _buildSimpleEntitlementCard(double? riceKg, double? wheatKg) {
    final hasData = riceKg != null && wheatKg != null && (riceKg + wheatKg) > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('beneficiary.home.monthly_title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.2)),
          const SizedBox(height: 12),
          if (!hasData)
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppConstants.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('beneficiary.home.entitlement_unavailable'), style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary))),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildCommodityPill('🍚', tr('beneficiary.home.rice_label'), '${riceKg!.toStringAsFixed(1)} kg', const Color(0xFF1A3D6B))),
                const SizedBox(width: 10),
                Expanded(child: _buildCommodityPill('🌾', tr('beneficiary.home.wheat_label'), '${wheatKg!.toStringAsFixed(1)} kg', const Color(0xFF065F46))),
              ],
            ),
          if (_entitlement?.rationReceivedForCycle == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tr('beneficiary.select.already_received_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF15803D)))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommodityPill(String emoji, String label, String qty, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          Text(qty, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildActionTile({required String emoji, required String label, required Color color, required String id, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key(id),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.78)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showShopSheet() {
    final fps = _beneficiary?.registeredFpsId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('🏪', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(tr('beneficiary.shop.title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
            const SizedBox(height: 16),
            if (fps == null || _beneficiary == null)
              Text(tr('beneficiary.shop.unavailable'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary))
            else ...[
              _buildShopRow(Icons.storefront_outlined, 'FPS ID', fps),
              if (_beneficiary!.nameForDemo.isNotEmpty)
                _buildShopRow(Icons.person_outline, 'Registered for', _beneficiary!.nameForDemo),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(tr('nav.close'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppConstants.textSecondary),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy))),
        ],
      ),
    );
  }

  void _showTrackSheet() {
    final orders = _getCombinedDeliveryOrders();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        builder: (_, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🚚', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(tr('beneficiary.track.title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                Text(
                  _deliveryRecords.isEmpty ? tr('beneficiary.track.no_requests') : tr('beneficiary.track.unavailable'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
                )
              else
                ...orders.take(3).map((order) => _buildSimpleTrackCard(order)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(tr('nav.close'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleTrackCard(CombinedCitizenDeliveryOrder order) {
    final stages = [
      tr('beneficiary.track.stage1'),
      tr('beneficiary.track.stage2'),
      tr('beneficiary.track.stage3'),
      tr('beneficiary.track.stage4'),
      tr('beneficiary.track.stage5'),
    ];
    final statusUpper = order.deliveryStatus.toUpperCase();
    int currentStage = 0;
    if (statusUpper.contains('ALLOCATED') || statusUpper.contains('APPROVED')) {
      currentStage = 1;
    } else if (statusUpper.contains('OUT_FOR') || statusUpper.contains('DISPATCHED') || statusUpper.contains('DELAYED') || statusUpper.contains('STOCK')) {
      currentStage = 2;
    } else if (statusUpper.contains('DELIVERED') && !statusUpper.contains('CONFIRMED')) {
      currentStage = 3;
    } else if (statusUpper.contains('CONFIRMED')) {
      currentStage = 4;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order: ${order.baseRequestId}', style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(stages.length, (i) {
              final isDone = i <= currentStage;
              final isCurrent = i == currentStage;
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isDone ? AppConstants.successGreen : const Color(0xFFE2E8F0),
                                  shape: BoxShape.circle,
                                  border: isCurrent ? Border.all(color: AppConstants.successGreen, width: 2) : null,
                                ),
                                child: Center(
                                  child: isDone
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : Text('${i + 1}', style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stages[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500, color: isDone ? AppConstants.successGreen : AppConstants.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (i < stages.length - 1)
                          Container(width: 8, height: 2, margin: const EdgeInsets.only(bottom: 20), color: i < currentStage ? AppConstants.successGreen : const Color(0xFFE2E8F0)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('🆘', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(tr('beneficiary.help.title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
            const SizedBox(height: 16),
            ...[
              (tr('beneficiary.help.no_ration'), Icons.no_food_outlined),
              (tr('beneficiary.help.wrong_qty'), Icons.balance_outlined),
              (tr('beneficiary.help.shop_problem'), Icons.storefront_outlined),
              (tr('beneficiary.help.payment'), Icons.receipt_long_outlined),
              (tr('beneficiary.help.other'), Icons.help_outline_rounded),
            ].map((item) => _buildHelpOptionTile(ctx, item.$1, item.$2)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: OutlinedButton.styleFrom(foregroundColor: AppConstants.primaryNavy, side: const BorderSide(color: AppConstants.cardBorder), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(tr('nav.cancel'), style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOptionTile(BuildContext sheetCtx, String label, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.of(sheetCtx).pop();
        _navigateToIntentHistory();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppConstants.primaryNavy),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppConstants.textPrimary))),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppConstants.textSecondary),
          ],
        ),
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
        VoicePictorialAssistButton(
          isCompact: true,
          onTap: () {
            VoicePictorialAssistModal.show(
              context,
              onApplyVoiceIntent: (mode, rice, wheat) {
                _navigateToIntentSelection();
              },
            );
          },
        ),
        const SizedBox(width: 4),
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

  // 2. HERO: YOUR RATION ENTITLEMENT CARD (Monthly Quota Only)
  Widget _buildHeroRationEntitlementCard() {
    final riceTotal = _entitlement != null ? _entitlement!.statutoryEntitlementRiceKg : (_eligibleMembersCount * 4.0);
    final wheatTotal = _entitlement != null ? _entitlement!.statutoryEntitlementWheatKg : (_eligibleMembersCount * 1.0);
    final totalEntitlementKg = _entitlement != null && _entitlement!.totalEligibleBalanceKg > 0
        ? _entitlement!.totalEligibleBalanceKg
        : (riceTotal + wheatTotal);
    final membersCount = _entitlement != null && _entitlement!.familyMembersCount > 0
        ? _entitlement!.familyMembersCount
        : _eligibleMembersCount;

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

          // Main Hero Highlight: Statutory Monthly Quota (Clean & Direct)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 440;
              final leftCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STATUTORY MONTHLY RATION QUOTA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalEntitlementKg.toStringAsFixed(1),
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
                    '${tr('commodity.rice')}: ${riceTotal.toStringAsFixed(1)} ${tr('commodity.kg')}  •  ${tr('commodity.wheat')}: ${wheatTotal.toStringAsFixed(1)} ${tr('commodity.kg')}',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              );

              final rightPill = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    const Text('Government Subsidy', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
                    const SizedBox(height: 2),
                    const Text(
                      '100% FREE',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF86EFAC)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$membersCount Eligible Members',
                      style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                    ),
                  ],
                ),
              );

              return Container(
                padding: const EdgeInsets.all(AppConstants.space16),
                decoration: BoxDecoration(
                  color: AppConstants.primaryNavy,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          leftCol,
                          const SizedBox(height: 12),
                          rightPill,
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: leftCol),
                          const SizedBox(width: 12),
                          rightPill,
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Monthly Entitlement Summary Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    'Monthly Quota: ${totalEntitlementKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
                  ),
                  Container(margin: const EdgeInsets.symmetric(horizontal: 10), width: 1, height: 12, color: Colors.grey.shade300),
                  Text(
                    'Rice: ${riceTotal.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                  ),
                  Container(margin: const EdgeInsets.symmetric(horizontal: 10), width: 1, height: 12, color: Colors.grey.shade300),
                  Text(
                    'Wheat: ${wheatTotal.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
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

    final hasCompletedDelivery = _deliveryRecords.any((r) => r.deliveryStatus == 'DELIVERY_CONFIRMED' || r.citizenConfirmedAt != null);
    final hasPlanLocked = _entitlement?.rationReceivedForCycle == true || _userSubmittedChoice || hasCompletedDelivery;
    final activeFpsName = _deliveryRecords.isNotEmpty
        ? (_deliveryRecords.first.intendedFpsName ?? _deliveryRecords.first.registeredFpsName ?? homeFpsName)
        : (_activeIntents.isNotEmpty ? _activeIntents.first.intendedFpsName : homeFpsName);

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
          buttonLabel: hasPlanLocked ? '✓ Plan Locked ($activeFpsName)' : tr('service.fps_choice_btn'),
          buttonIcon: hasPlanLocked ? Icons.lock_rounded : Icons.store_rounded,
          isPrimary: !hasPlanLocked,
          onTap: () {
            if (hasPlanLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Your collection plan for $activeFpsName (Cycle 2026-09) is registered and locked in pre-dispatch logistics.'),
                  backgroundColor: const Color(0xFF15803D),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              _navigateToIntentSelection(initialMode: 'FPS_COLLECTION');
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

  // 0c. VOICE & PICTORIAL ACCESSIBILITY ASSISTANT BANNER (FOR LOW-LITERACY BENEFICIARIES)
  Widget _buildVoicePictorialAssistBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0F2942)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F2942).withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF38BDF8)),
            ),
            child: const Icon(Icons.mic_rounded, color: Color(0xFF38BDF8), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🎙️ Voice & Pictorial Assist', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Color(0xFF16A34A), borderRadius: BorderRadius.all(Radius.circular(4))),
                      child: Text('ACCESSIBILITY MODE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text('Tap to speak intent or use visual picture cards in English, Hindi, or Kannada.', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showVoicePictorialAssistModal,
            icon: const Icon(Icons.record_voice_over_rounded, size: 16),
            label: const Text('Voice Assist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoicePictorialAssistModal() {
    String selectedLang = 'KN'; // EN, HI, KN
    double voiceRiceKg = (_eligibleMembersCount * 4.0).clamp(0.0, 40.0);
    double voiceWheatKg = (_eligibleMembersCount * 1.0).clamp(0.0, 20.0);
    String selectedFpsId = _beneficiary?.registeredFpsId ?? 'FPS-KA-BLR-001';
    bool isListening = false;
    bool isSubmitting = false;
    String feedbackText = '🔊 "ನಿಮ್ಮ 5 ಸದಸ್ಯರ ಕುಟುಂಬಕ್ಕೆ 16 ಕೆಜಿ ಅಕ್ಕಿ ಮತ್ತು 4 ಕೆಜಿ ಗೋಧಿ ಧಾನ್ಯ ಅರ್ಹತೆಯಿದೆ. ಧ್ವನಿ ಮೂಲಕ ನೋಂದಾಯಿಸಲು ಮೈಕ್ ಒತ್ತಿ."';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0xFF15803D), shape: BoxShape.circle),
                  child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Voice & Pictorial Assist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('ಧ್ವನಿ ಮತ್ತು ಚಿತ್ರಾತ್ಮಕ ನೆರವು • आवाज सहायता (Low Literacy Mode)', style: TextStyle(fontSize: 10.5, color: AppConstants.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Regional Language Selector Chips
                  Row(
                    children: [
                      const Text('Language / ಭಾಷೆ:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('🇬🇧 EN', style: TextStyle(fontSize: 11)),
                        selected: selectedLang == 'EN',
                        selectedColor: AppConstants.primaryNavy,
                        labelStyle: TextStyle(color: selectedLang == 'EN' ? Colors.white : Colors.black87),
                        onSelected: (_) {
                          setModalState(() {
                            selectedLang = 'EN';
                            feedbackText = '🔊 "Your family entitlement is ${voiceRiceKg.toInt()} kg Rice & ${voiceWheatKg.toInt()} kg Wheat. Tap microphone to speak your intent."';
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('🇮🇳 हिंदी', style: TextStyle(fontSize: 11)),
                        selected: selectedLang == 'HI',
                        selectedColor: AppConstants.primaryNavy,
                        labelStyle: TextStyle(color: selectedLang == 'HI' ? Colors.white : Colors.black87),
                        onSelected: (_) {
                          setModalState(() {
                            selectedLang = 'HI';
                            feedbackText = '🔊 "आपके परिवार के लिए ${voiceRiceKg.toInt()} किग्रा चावल और ${voiceWheatKg.toInt()} किग्रा गेहूं का कोटा है। बोलने के लिए माइक दबाएं।"';
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('🇮🇳 ಕನ್ನಡ', style: TextStyle(fontSize: 11)),
                        selected: selectedLang == 'KN',
                        selectedColor: AppConstants.primaryNavy,
                        labelStyle: TextStyle(color: selectedLang == 'KN' ? Colors.white : Colors.black87),
                        onSelected: (_) {
                          setModalState(() {
                            selectedLang = 'KN';
                            feedbackText = '🔊 "ನಿಮ್ಮ ಕುಟುಂಬಕ್ಕೆ ${voiceRiceKg.toInt()} ಕೆಜಿ ಅಕ್ಕಿ ಮತ್ತು ${voiceWheatKg.toInt()} ಕೆಜಿ ಗೋಧಿ ಧಾನ್ಯ ಅರ್ಹತೆಯಿದೆ. ಧ್ವನಿ ಮೂಲಕ ನೋಂದಾಯಿಸಲು ಮೈಕ್ ಒತ್ತಿ."';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Audio Speech Output Banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up_rounded, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feedbackText,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Pictorial Commodity Selection Cards (Zero-Text Touch Targets)
                  const Text('1. Tap Pictures to Select Commodities:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Fortified Rice Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.rice_bowl_rounded, size: 36, color: Color(0xFF16A34A)),
                              const SizedBox(height: 4),
                              Text(selectedLang == 'KN' ? 'ಅಕ್ಕಿ (Rice)' : (selectedLang == 'HI' ? 'चावल (Rice)' : 'Fortified Rice'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        if (voiceRiceKg > 0) voiceRiceKg -= 1.0;
                                      });
                                    },
                                  ),
                                  Text('${voiceRiceKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        voiceRiceKg += 1.0;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Whole Wheat Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD97706), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.grain_rounded, size: 36, color: Color(0xFFD97706)),
                              const SizedBox(height: 4),
                              Text(selectedLang == 'KN' ? 'ಗೋಧಿ (Wheat)' : (selectedLang == 'HI' ? 'गेहूं (Wheat)' : 'Whole Wheat'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        if (voiceWheatKg > 0) voiceWheatKg -= 1.0;
                                      });
                                    },
                                  ),
                                  Text('${voiceWheatKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () {
                                      setModalState(() {
                                        voiceWheatKg += 1.0;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. Microphone Voice Command Simulator
                  const Text('2. Speak Intent Command:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isListening = true;
                              feedbackText = selectedLang == 'KN'
                                  ? '🎙️ "ಕೇಳಿಸಿಕೊಳ್ಳುತ್ತಿದ್ದೇವೆ... ಅಕ್ಕಿ ${voiceRiceKg.toInt()}ಕೆಜಿ, ಗೋಧಿ ${voiceWheatKg.toInt()}ಕೆಜಿ ಆಯ್ಕೆಯಾಗಿದೆ."'
                                  : '🎙️ "Listening... Selected ${voiceRiceKg.toInt()}kg Rice & ${voiceWheatKg.toInt()}kg Wheat."';
                            });
                            Future.delayed(const Duration(milliseconds: 1200), () {
                              setModalState(() {
                                isListening = false;
                                feedbackText = selectedLang == 'KN'
                                    ? '✅ "ಧ್ವನಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ! ಸಲ್ಲಿಸಲು ಕೆಳಗಿನ ಬಟನ್ ಒತ್ತಿ."'
                                    : '✅ "Voice Command Captured! Press Confirm to submit."';
                              });
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isListening ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isListening ? const Color(0xFFDC2626) : const Color(0xFF15803D)).withValues(alpha: 0.4),
                                  blurRadius: isListening ? 20 : 10,
                                  spreadRadius: isListening ? 6 : 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isListening
                              ? (selectedLang == 'KN' ? 'ಧ್ವನಿ ಗ್ರಹಿಸಲಾಗುತ್ತಿದೆ...' : 'Listening to your voice...')
                              : (selectedLang == 'KN' ? 'ಮಾತನಾಡಲು ಮೈಕ್ ಒತ್ತಿ' : 'Tap Mic to Speak Intent'),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isListening ? const Color(0xFFDC2626) : AppConstants.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Voice Presets
                  const Text('Quick Spoken Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.textSecondary)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.mic, size: 14),
                        label: Text(selectedLang == 'KN' ? 'ನನ್ನ ಅಂಗಡಿಯಲ್ಲಿ ಪೂರ್ಣ ಪಡಿತರ' : 'Full Quota at Home Shop', style: const TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          setModalState(() {
                            voiceRiceKg = (_eligibleMembersCount * 4.0).clamp(0.0, 40.0);
                            voiceWheatKg = (_eligibleMembersCount * 1.0).clamp(0.0, 20.0);
                            feedbackText = selectedLang == 'KN'
                                ? '🔊 "ಪೂರ್ಣ ಕೋಟಾ ಆಯ್ಕೆಯಾಗಿದೆ: ${voiceRiceKg.toInt()} ಕೆಜಿ ಅಕ್ಕಿ, ${voiceWheatKg.toInt()} ಕೆಜಿ ಗೋಧಿ."'
                                : '🔊 "Full Quota Selected: ${voiceRiceKg.toInt()} kg Rice, ${voiceWheatKg.toInt()} kg Wheat."';
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.local_shipping, size: 14),
                        label: Text(selectedLang == 'KN' ? 'ಮನೆ ಬಾಗಿಲಿಗೆ ವಿತರಣೆ' : 'Doorstep Delivery', style: const TextStyle(fontSize: 10.5)),
                        onPressed: () {
                          setModalState(() {
                            feedbackText = selectedLang == 'KN'
                                ? '🔊 "ಮನೆ ಬಾಗಿಲಿಗೆ ವಿತರಣೆ ಆಯ್ಕೆಯಾಗಿದೆ."'
                                : '🔊 "Doorstep Home Delivery Selected."';
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel / ರದ್ದು'),
              ),
              ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          await _apiService.submitIntent(
                            beneficiaryId: widget.beneficiaryId,
                            intendedFpsId: selectedFpsId,
                            commodityOption: 'Both',
                            riceQuantityKg: voiceRiceKg,
                            wheatQuantityKg: voiceWheatKg,
                            cycleId: '2026-09',
                          );
                          if (!mounted) return;
                          Navigator.of(ctx).pop();
                          _loadBeneficiaryData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                selectedLang == 'KN'
                                    ? '✅ ಧ್ವನಿ ಮೂಲಕ ಬೇಡಿಕೆ ಯಶಸ್ವಿಯಾಗಿ ಸಲ್ಲಿಸಲಾಗಿದೆ! (Intent Registered via Voice)'
                                    : '✅ Intent Registered via Voice Assistant! Ticket QR Generated.',
                              ),
                              backgroundColor: const Color(0xFF15803D),
                            ),
                          );
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Submission Error: $e'), backgroundColor: AppConstants.dangerRed),
                          );
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 16),
                label: Text(selectedLang == 'KN' ? 'ಸಲ್ಲಿಸಿ (Confirm)' : 'Confirm Voice Intent'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }
}
