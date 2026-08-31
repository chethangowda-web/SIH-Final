import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/delivery_timeline.dart';
import 'intent_selection_screen.dart';
import 'intent_history_screen.dart';
import 'demo_login_screen.dart';

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
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadBeneficiaryData();
  }

  Future<void> _loadBeneficiaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await _apiService.fetchBeneficiaryDetail(widget.beneficiaryId);
      final intents = await _apiService.fetchBeneficiaryIntents(
        widget.beneficiaryId,
        cycleId: '2026-09',
      );

      BeneficiaryEntitlementSummary? ent;
      try {
        ent = await _apiService.fetchBeneficiaryEntitlementSummary(
          widget.beneficiaryId,
          cycleId: '2026-09',
        );
      } catch (_) {}

      List<CitizenDeliveryRecord> records = [];
      try {
        records = await _apiService.fetchBeneficiaryDeliveryRecords(
          widget.beneficiaryId,
          cycleId: '2026-09',
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _beneficiary = detail;
          _entitlement = ent;
          _activeIntents = intents;
          _deliveryRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load beneficiary profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToIntentSelection({String initialMode = 'FPS_COLLECTION'}) async {
    if (_beneficiary == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntentSelectionScreen(
          beneficiary: _beneficiary!,
          apiService: _apiService,
          initialDeliveryMode: initialMode,
        ),
      ),
    );

    if (result == true || result == null) {
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

  void _confirmFullReceipt(CitizenDeliveryRecord record) async {
    try {
      await _apiService.confirmCitizenDelivery(
        beneficiaryId: widget.beneficiaryId,
        requestId: record.requestId,
        confirmationStatus: 'DELIVERY_CONFIRMED',
        receivedRiceKg: record.commodity == 'Rice' ? record.authorizedQuantityKg : 0.0,
        receivedWheatKg: record.commodity == 'Wheat' ? record.authorizedQuantityKg : 0.0,
      );
      _loadBeneficiaryData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery confirmed! Digital receipt registered with district supply office.'),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Confirmation failed: $e'), backgroundColor: AppConstants.dangerRed),
      );
    }
  }

  void _showDeliveryDisputeModal(CitizenDeliveryRecord record) {
    final qtyCtrl = TextEditingController(
      text: (record.authorizedQuantityKg > 0 ? record.authorizedQuantityKg : record.requestedQuantityKg).toStringAsFixed(1),
    );
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
          final expectedQty = record.authorizedQuantityKg > 0 ? record.authorizedQuantityKg : record.requestedQuantityKg;
          final receivedVal = double.tryParse(qtyCtrl.text) ?? expectedQty;
          final shortfall = (expectedQty - receivedVal).clamp(0.0, 999.0);

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
                      const Row(
                        children: [
                          Icon(Icons.report_problem_outlined, color: AppConstants.dangerRed, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Report Delivery Discrepancy',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
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
                    'Order #${record.requestId} • Entitled Quota: ${expectedQty.toStringAsFixed(1)} kg ${record.commodity}',
                    style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Shortfall summary pill
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Detected Shortfall:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.dangerRed)),
                        Text(
                          '${shortfall.toStringAsFixed(1)} kg ${record.commodity}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppConstants.dangerRed),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Actual Quantity Received (kg)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.scale_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Discrepancy Details / Remarks',
                      hintText: 'e.g. Weighment deficit, damaged packaging, missing items',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
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
                              final actualKg = double.tryParse(qtyCtrl.text) ?? 0.0;
                              await _apiService.confirmCitizenDelivery(
                                beneficiaryId: widget.beneficiaryId,
                                requestId: record.requestId,
                                confirmationStatus: 'DELIVERY_DISPUTE',
                                receivedRiceKg: record.commodity == 'Rice' ? actualKg : 0.0,
                                receivedWheatKg: record.commodity == 'Wheat' ? actualKg : 0.0,
                                disputeNotes: notesCtrl.text.trim(),
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _loadBeneficiaryData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Dispute recorded. Submitted to District Supply Officer (DSO) for inquiry.'),
                                  backgroundColor: AppConstants.accentAmber,
                                ),
                              );
                            } catch (e) {
                              setModalState(() {
                                isProcessing = false;
                                modalError = e.toString();
                              });
                            }
                          },
                    icon: isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Submit Formal Dispute to DSO Queue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.dangerRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  if (modalError != null) ...[
                    const SizedBox(height: 8),
                    Text(modalError!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
                  ],
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
    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: _buildGovernmentAppBar(),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5, color: AppConstants.primaryNavy),
                  SizedBox(height: 16),
                  Text('Loading verified government entitlement record...', style: TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
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
                          label: const Text('Try Again'),
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
                            // 1. Beneficiary Profile & Card Identity Card
                            _buildBeneficiaryProfileCard(),
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
                                'DEPARTMENT OF FOOD & CIVIL SUPPLIES • GOVERNMENT OF KARNATAKA\nALL FOODGRAINS UNDER NFSA ARE 100% SUBSIDIZED (₹0.00/KG)',
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PDS DemandSync • Citizen Beneficiary Portal',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: 0.2),
              ),
              Text(
                'National Food Security Act (NFSA) • Public Distribution Services',
                style: TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh Entitlement',
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: _loadBeneficiaryData,
        ),
        IconButton(
          tooltip: 'View Signal History',
          icon: const Icon(Icons.history_rounded, size: 20),
          onPressed: _navigateToIntentHistory,
        ),
        IconButton(
          tooltip: 'Exit Portal',
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
    final familyCount = _entitlement?.familyMembersCount ?? 4;

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
                      child: const Text(
                        'Cycle 7 · Sep 2026',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
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
                      'Ration Card: ${b.pseudonymousBeneficiaryId}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
                    ),
                    Text(
                      '• $cardLabel ($familyCount Members)',
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

  // 2. HERO: YOUR RATION ENTITLEMENT CARD
  Widget _buildHeroRationEntitlementCard() {
    final riceTotal = _entitlement?.statutoryEntitlementRiceKg ?? 20.0;
    final wheatTotal = _entitlement?.statutoryEntitlementWheatKg ?? 5.0;
    final totalEntitlementKg = riceTotal + wheatTotal;

    final riceConsumed = _entitlement?.consumedRiceKg ?? 0.0;
    final wheatConsumed = _entitlement?.consumedWheatKg ?? 0.0;
    final totalConsumedKg = riceConsumed + wheatConsumed;

    final riceRemaining = _entitlement?.remainingEligibleRiceKg ?? 20.0;
    final wheatRemaining = _entitlement?.remainingEligibleWheatKg ?? 5.0;
    final remainingBalanceKg = _entitlement?.totalEligibleBalanceKg ?? 25.0;

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
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in_outlined, color: AppConstants.accentBlue, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'YOUR RATION ENTITLEMENT',
                    style: TextStyle(
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
                child: const Text(
                  '100% SUBSIDIZED @ ₹0.00/kg',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AVAILABLE REMAINING BALANCE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.5),
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
                        const Text(
                          'KG',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rice: ${riceRemaining.toStringAsFixed(1)} kg  •  Wheat: ${wheatRemaining.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
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
                      const Text('Total Monthly Quota', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
                      const SizedBox(height: 2),
                      Text(
                        '${totalEntitlementKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Consumed: ${totalConsumedKg.toStringAsFixed(1)} kg',
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
                    'Monthly Lifting Progress: ${(progressFraction * 100).toStringAsFixed(0)}% Lifted',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                  ),
                  Text(
                    '${remainingBalanceKg.toStringAsFixed(1)} kg Remaining to Collect',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppConstants.successGreen),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.accentBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space14),

          // Reassuring Statutory Policy Notice
          Container(
            padding: const EdgeInsets.all(AppConstants.space12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 16, color: AppConstants.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your ration entitlement is determined by government policy. You cannot increase or customize the quantity.',
                    style: TextStyle(fontSize: 11.5, color: AppConstants.textSecondary, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. PLAN YOUR UPCOMING COLLECTION (Two Large Service Cards)
  Widget _buildPlanCollectionSection() {
    final homeFpsName = _beneficiary?.registeredFpsName ?? 'Malleshwaram Seva Kendra (Demo)';
    final homeFpsId = _beneficiary?.registeredFpsId ?? 'FPS-KA-BLR-001';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PLAN YOUR UPCOMING COLLECTION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppConstants.primaryNavy,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Declare your intended pickup channel in advance to guarantee zero-stockout allocation.',
          style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: AppConstants.space12),

        // Two Large Service Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 580;

            final card1 = _buildServiceChoiceCard(
              title: 'Collect at Fair Price Shop',
              icon: Icons.storefront_outlined,
              iconColor: AppConstants.primaryNavy,
              iconBg: const Color(0xFFEFF6FF),
              badgeText: 'FREE PICKUP',
              badgeColor: AppConstants.accentBlue,
              description: 'Pick up your monthly grain quota at your designated Fair Price Shop or any ONORC portability center.',
              contextDetail: 'Home Center: $homeFpsName ($homeFpsId)',
              priceTag: 'Cost: ₹0.00 (Zero Delivery Fee)',
              buttonLabel: 'Select Shop',
              buttonIcon: Icons.store_rounded,
              isPrimary: true,
              onTap: () => _navigateToIntentSelection(initialMode: 'FPS_COLLECTION'),
            );

            final card2 = _buildServiceChoiceCard(
              title: 'Assisted Home Delivery',
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFFD97706),
              iconBg: const Color(0xFFFEF3C7),
              badgeText: 'DOORSTEP SERVICE',
              badgeColor: const Color(0xFFD97706),
              description: 'Direct doorstep delivery to your home address. Designed for senior citizens, disabled, and busy workers.',
              contextDetail: 'Foodgrain cost: ₹0 (100% Subsidized)',
              priceTag: 'Transport fee only: From ₹20 base fee',
              buttonLabel: 'Choose Delivery',
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
        const SizedBox(height: AppConstants.space12),

        // Transparent Policy Clarification Banner
        Container(
          padding: const EdgeInsets.all(AppConstants.space12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Home delivery charges apply only to transportation/logistics. They do not purchase or increase your ration entitlement.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
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

  // 4. CURRENT REQUEST / DELIVERY STATUS (5-Stage Timeline)
  Widget _buildCurrentDeliveryStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CURRENT REQUEST / DELIVERY STATUS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppConstants.primaryNavy,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppConstants.space12),

        ..._deliveryRecords.map((record) {
          final statusKey = record.citizenConfirmedAt != null
              ? 'DELIVERY_CONFIRMED'
              : (record.disputeReason != null ? 'DELIVERY_DISPUTE' : record.deliveryStatus);
          final isConfirmed = statusKey == 'DELIVERY_CONFIRMED';
          final isDispute = statusKey == 'DELIVERY_DISPUTE';
          final qty = record.authorizedQuantityKg > 0 ? record.authorizedQuantityKg : record.requestedQuantityKg;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: AppConstants.primaryNavy, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Order #${record.requestId}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppConstants.textPrimary),
                        ),
                      ],
                    ),
                    StatusBadge(status: statusKey),
                  ],
                ),
                const SizedBox(height: 12),

                // 5-Stage Timeline
                DeliveryTimeline(currentStatus: statusKey),
                const SizedBox(height: 14),

                // Details Row
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Authorized: ${qty.toStringAsFixed(1)} kg ${record.commodity} • ${record.deliveryMode.replaceAll('_', ' ')}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppConstants.textPrimary),
                      ),
                      if (record.transportFeeInr > 0)
                        Text(
                          'Logistics Fee: ₹${record.transportFeeInr.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                        ),
                    ],
                  ),
                ),

                // If Dispute
                if (isDispute && record.disputeReason != null) ...[
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
                            'Dispute Reason: ${record.disputeReason} (Under DSO Investigation)',
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
                  const Text(
                    'Did you receive your ration?',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmFullReceipt(record),
                          icon: const Icon(Icons.check_circle_outline, size: 15),
                          label: const Text('Yes, I received full quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                          onPressed: () => _showDeliveryDisputeModal(record),
                          icon: const Icon(Icons.report_problem_outlined, size: 15),
                          label: const Text('Report quantity issue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
              const Text(
                'RECENT DISTRIBUTION & PREFERENCE HISTORY',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryNavy,
                  letterSpacing: 0.5,
                ),
              ),
              TextButton(
                onPressed: _navigateToIntentHistory,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                child: const Text('View All Timeline →', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppConstants.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'No active signals recorded yet for Cycle 7 · September 2026.',
                    style: TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
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
