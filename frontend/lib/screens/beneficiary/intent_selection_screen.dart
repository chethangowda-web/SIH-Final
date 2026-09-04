import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
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
    this.initialEligibleMembersCount = 4,
  });

  @override
  State<IntentSelectionScreen> createState() => _IntentSelectionScreenState();
}

class _IntentSelectionScreenState extends State<IntentSelectionScreen> {
  late final ApiService _apiService;
  List<FpsShop> _fpsList = [];
  FpsShop? _selectedFps;
  BeneficiaryEntitlementSummary? _entitlement;
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
    _eligibleMembersCount = widget.initialEligibleMembersCount;
    _riceQtyKg = _eligibleMembersCount * 4.0;
    _wheatQtyKg = _eligibleMembersCount * 1.0;
    _loadData();
  }

  double get _maxHouseholdEntitlementKg => _eligibleMembersCount * 5.0;
  double get _combinedQtyKg => _riceQtyKg + _wheatQtyKg;
  bool get _isOverEntitled => _combinedQtyKg > _maxHouseholdEntitlementKg;

  @override
  void dispose() {
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
      try {
        ent = await _apiService.fetchBeneficiaryEntitlementSummary(
          widget.beneficiary.pseudonymousBeneficiaryId,
          cycleId: '2026-09',
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _fpsList = list;
          _entitlement = ent;

          // Default to home registered shop
          _selectedFps = _fpsList.where((fps) => fps.fpsId == widget.beneficiary.registeredFpsId).firstOrNull ??
              (_fpsList.isNotEmpty ? _fpsList.first : null);

          // Sync member count authoritatively from government entitlement record.
          // This ensures the displayed count matches the verified ration card registry,
          // not a client-side default. Rice = 4kg/member, Wheat = 1kg/member.
          if (ent != null) {
            _eligibleMembersCount = ent.familyMembersCount;
            _riceQtyKg = ent.statutoryEntitlementRiceKg;
            _wheatQtyKg = ent.statutoryEntitlementWheatKg;
          }

          _isLoading = false;
        });
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

  void _continueToReview() async {
    if (_selectedFps == null || _isOverEntitled || _entitlement?.rationReceivedForCycle == true) return;

    final distance = _getCalculatedDistance(_selectedFps!);
    final fee = _calculateTransportFee(distance);

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntentConfirmationScreen(
          beneficiary: widget.beneficiary,
          intendedFps: _selectedFps!,
          commodityOption: 'Both',
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

    final riceTotal = _entitlement?.statutoryEntitlementRiceKg ?? 20.0;
    final wheatTotal = _entitlement?.statutoryEntitlementWheatKg ?? 5.0;
    final totalMonthly = riceTotal + wheatTotal;

    final riceConsumed = _entitlement?.consumedRiceKg ?? 0.0;
    final wheatConsumed = _entitlement?.consumedWheatKg ?? 0.0;
    final totalConsumed = riceConsumed + wheatConsumed;

    final remainingBalance = _entitlement?.totalEligibleBalanceKg ?? 25.0;

    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppConstants.backgroundLight,
          appBar: AppBar(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 16,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('intent.screen_title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                ),
                Text(
                  tr('app.nfsa_notice'),
                  style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                ),
              ],
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LanguageSelectorWidget(isCompact: true),
              ),
              SizedBox(width: 8),
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
                          _buildCitizenStepper(),
                          const SizedBox(height: AppConstants.space20),
                          _buildSection1ServicePreference(),
                          const SizedBox(height: AppConstants.space20),
                          _buildSection2FpsSelection(),
                          const SizedBox(height: AppConstants.space20),
                          if (_deliveryMode == 'HOME_DELIVERY') ...[
                            _buildSection3HomeDeliveryLogistics(selectedDist, transportFee),
                            const SizedBox(height: AppConstants.space20),
                          ],
                          _buildSectionHouseholdMembersAndAllocation(),
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

  Widget _buildCitizenStepper() {
    final steps = [
      {'num': '1', 'title': tr('intent.step_service'), 'active': true},
      {'num': '2', 'title': tr('intent.step_fps'), 'active': true},
      {'num': '3', 'title': tr('intent.step_review'), 'active': false},
      {'num': '4', 'title': tr('intent.step_confirm'), 'active': false},
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
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final step = entry.value;
          final isFirst = idx == 0;
          final isSecond = idx == 1;

          return Expanded(
            child: Row(
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
                Flexible(
                  child: Text(
                    step['title'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isFirst || isSecond ? FontWeight.w800 : FontWeight.w500,
                      color: isFirst || isSecond ? AppConstants.primaryNavy : AppConstants.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (idx < steps.length - 1) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 1.5,
                      color: isFirst ? AppConstants.primaryNavy : const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // SECTION 1: HOW WOULD YOU LIKE TO RECEIVE YOUR RATION?
  Widget _buildSection1ServicePreference() {
    final isFps = _deliveryMode == 'FPS_COLLECTION';
    final isHome = _deliveryMode == 'HOME_DELIVERY';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('intent.section1_title'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppConstants.primaryNavy,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('intent.section1_subtitle'),
          style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: AppConstants.space12),

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 580;

            final cardA = _buildSelectableServiceCard(
              title: tr('intent.fps_choice_title'),
              subtitle: tr('service.fps_choice_desc'),
              icon: Icons.storefront_outlined,
              isSelected: isFps,
              costText: tr('service.fps_choice_price'),
              costColor: const Color(0xFF15803D),
              badgeText: tr('service.fps_choice_badge'),
              onTap: () => setState(() => _deliveryMode = 'FPS_COLLECTION'),
            );

            final cardB = _buildSelectableServiceCard(
              title: tr('intent.home_choice_title'),
              subtitle: tr('service.home_choice_desc'),
              icon: Icons.local_shipping_outlined,
              isSelected: isHome,
              costText: tr('service.home_choice_price'),
              costColor: const Color(0xFFB45309),
              badgeText: tr('service.home_choice_badge'),
              onTap: () => setState(() => _deliveryMode = 'HOME_DELIVERY'),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cardA),
                  const SizedBox(width: 14),
                  Expanded(child: cardB),
                ],
              );
            } else {
              return Column(
                children: [
                  cardA,
                  const SizedBox(height: 12),
                  cardB,
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSelectableServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required String costText,
    required Color costColor,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.space16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : AppConstants.cardSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: isSelected ? AppConstants.accentBlue : AppConstants.cardBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppConstants.accentBlue.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 8 : 4,
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
                  decoration: BoxDecoration(
                    color: isSelected ? AppConstants.accentBlue.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: isSelected ? AppConstants.accentBlue : AppConstants.primaryNavy, size: 22),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppConstants.accentBlue.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppConstants.accentBlue : AppConstants.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isSelected ? AppConstants.accentBlue : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppConstants.accentBlue : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppConstants.primaryNavy : AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 10),
            Text(
              costText,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: costColor),
            ),
          ],
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
              onTap: () => setState(() => _selectedFps = fps),
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
                            '${fps.fpsId} • Distance: ${dist.toStringAsFixed(1)} km • Storage Capacity: ${(fps.capacityKg / 1000).toStringAsFixed(0)} MT',
                            style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                          ),
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

  // SECTION 3: HOME DELIVERY LOGISTICS SUMMARY
  Widget _buildSection3HomeDeliveryLogistics(double distanceKm, double transportFee) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFEF3C7).withValues(alpha: 0.1),
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
                  const Icon(Icons.receipt_long_outlined, color: Color(0xFFB45309), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    tr('intent.section3_title'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.primaryNavy,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('TRANSPARENT TARIFF', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Address Input
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: tr('intent.address_label'),
              hintText: 'Enter complete house number, street, landmark...',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),

          // Logistics Cost Breakdown Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Column(
              children: [
                _buildFeeRow(tr('entitlement.title'), 'Government determined', '₹0 foodgrain cost', isBold: true, highlightGreen: true),
                const Divider(height: 16),
                _buildFeeRow('TRANSPORTATION', '${distanceKm.toStringAsFixed(1)} km from ${_selectedFps?.name ?? "FPS"}', '₹${transportFee.toStringAsFixed(2)}'),
                const Divider(height: 16),
                _buildFeeRow('TOTAL PAYABLE AT DELIVERY', 'Logistics conveyance fee only', '₹${transportFee.toStringAsFixed(2)}', isBold: true, highlightNavy: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Subtle Policy Clarification Panel
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                    SizedBox(width: 6),
                    Text(
                      'Foodgrain is not being purchased. You are paying only for transportation/logistics.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tr('entitlement.statutory_rule'),
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String title, String subtitle, String value, {bool isBold = false, bool highlightGreen = false, bool highlightNavy = false}) {
    Color valColor = AppConstants.textPrimary;
    if (highlightGreen) valColor = const Color(0xFF15803D);
    if (highlightNavy) valColor = AppConstants.primaryNavy;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: AppConstants.primaryNavy)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
          ],
        ),
        Text(
          value,
          style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, color: valColor),
        ),
      ],
    );
  }

  // SECTION 4: ENTITLEMENT SUMMARY (Non-editable)
  Widget _buildSection4EntitlementSummary(double monthly, double consumed, double remaining) {
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
                'NON-EDITABLE',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppConstants.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildEntitlementBox(tr('entitlement.monthly_quota'), '${monthly.toStringAsFixed(1)} ${tr('commodity.kg')}', '${tr('commodity.rice')} + ${tr('commodity.wheat')}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEntitlementBox(tr('entitlement.consumed'), '${consumed.toStringAsFixed(1)} ${tr('commodity.kg')}', 'This Month'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEntitlementBox(tr('entitlement.remaining_balance'), '${remaining.toStringAsFixed(1)} ${tr('commodity.kg')}', 'Available to Lift', isHighlight: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEntitlementBox('Planning Cycle', 'Cycle 7', 'Sep 2026'),
              ),
            ],
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

  // SECTION: HOUSEHOLD MEMBERS & COMBINED FOODGRAIN ALLOCATION
  Widget _buildSectionHouseholdMembersAndAllocation() {
    final maxEntitlement = _maxHouseholdEntitlementKg;
    final combined = _combinedQtyKg;
    final isOver = _isOverEntitled;

    return Container(
      key: const ValueKey('section_household_allocation'),
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isOver ? AppConstants.dangerRed : AppConstants.accentBlue.withValues(alpha: 0.35),
          width: isOver ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOver ? AppConstants.dangerRed : AppConstants.accentBlue).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & 5 kg / person entitlement badge
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
          const SizedBox(height: 12),

          // READ-ONLY: Government-Controlled Verified Member Count
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verified Member Count Display (locked, government-controlled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppConstants.primaryNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.22), width: 1.4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppConstants.primaryNavy, size: 15),
                    const SizedBox(height: 3),
                    Text(
                      '$_eligibleMembersCount',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy),
                    ),
                    const Text(
                      'MEMBERS',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Govt-controlled badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF15803D)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              tr('members.govt_controlled'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Quota formula
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        tr('members.formula', params: {
                          'count': '$_eligibleMembersCount',
                          'max': maxEntitlement.toStringAsFixed(1),
                        }),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.accentBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Combined Foodgrain Allocation Heading
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('members.allocation_title'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.4),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOver ? const Color(0xFFFEF2F2) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isOver ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  '${combined.toStringAsFixed(1)} / ${maxEntitlement.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isOver ? AppConstants.dangerRed : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rice Allocation Row (Fixed / Read-Only Statutory Entitlement)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grass_rounded, color: AppConstants.primaryNavy, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('members.rice_alloc'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                      ),
                      const Text(
                        '100% Subsidized (₹0.00/kg) • Statutory Allocation',
                        style: TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 13, color: AppConstants.primaryNavy),
                      const SizedBox(width: 5),
                      Text(
                        '${_riceQtyKg.toStringAsFixed(1)} kg',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Wheat Allocation Row (Fixed / Read-Only Statutory Entitlement)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grain_rounded, color: Color(0xFFB45309), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('members.wheat_alloc'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                      ),
                      const Text(
                        '100% Subsidized (₹0.00/kg) • Statutory Allocation',
                        style: TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB45309).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 13, color: Color(0xFFB45309)),
                      const SizedBox(width: 5),
                      Text(
                        '${_wheatQtyKg.toStringAsFixed(1)} kg',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // CTA: SUBMIT BUTTON
  Widget _buildPrimarySubmitButton(double transportFee) {
    final isReceived = _entitlement?.rationReceivedForCycle == true;
    final isReady = _selectedFps != null && !_isOverEntitled && !isReceived;

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
                const Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFFB91C1C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('delivery.ration_received_desc'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7F1D1D)),
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
              tr('members.adjust_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.dangerRed),
            ),
          ),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const ValueKey('btn_continue_to_review'),
            onPressed: isReady ? _continueToReview : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              _deliveryMode == 'HOME_DELIVERY'
                  ? tr('intent.btn_continue_home', params: {'fee': transportFee.toStringAsFixed(2)})
                  : tr('intent.btn_continue_fps'),
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
