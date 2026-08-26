import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import 'intent_selection_screen.dart';
import 'intent_history_screen.dart';

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
  List<IntentRecord> _activeIntents = [];
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
      final detail =
          await _apiService.fetchBeneficiaryDetail(widget.beneficiaryId);
      final intents = await _apiService.fetchBeneficiaryIntents(
        widget.beneficiaryId,
        cycleId: '2026-09',
      );

      setState(() {
        _beneficiary = detail;
        _activeIntents = intents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load beneficiary profile: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToIntentSelection() async {
    if (_beneficiary == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntentSelectionScreen(
          beneficiary: _beneficiary!,
          apiService: _apiService,
        ),
      ),
    );

    if (result == true) {
      // Reload on return from successful submission
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beneficiary Portal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'PDS DemandSync • Forward-Looking Intent',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Profile',
            icon: const Icon(Icons.refresh),
            onPressed: _loadBeneficiaryData,
          ),
          IconButton(
            tooltip: 'View Intent History',
            icon: const Icon(Icons.history_rounded),
            onPressed: _navigateToIntentHistory,
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text(
                    'Loading beneficiary quota profile...',
                    style: TextStyle(color: AppConstants.textSecondary),
                  ),
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
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Beneficiary Profile Card
                            _buildProfileCard(),
                            const SizedBox(height: 16),

                            // 2. Upcoming Cycle Banner
                            _buildCycleBanner(),
                            const SizedBox(height: 16),

                            // 3. Commodity Entitlements Grid
                            _buildCommodityEntitlements(),
                            const SizedBox(height: 20),

                            // 4. Prominent Planning Intent Callout Card
                            _buildPlanningIntentCtaCard(),
                            const SizedBox(height: 16),

                            // 5. Active Intent Status (if already submitted)
                            if (_activeIntents.isNotEmpty) ...[
                              _buildActiveIntentsCard(),
                              const SizedBox(height: 16),
                            ],

                            // 6. Navigation Link to History
                            _buildHistoryQuickLink(),
                            const SizedBox(height: 24),

                            // Notice footer
                            Center(
                              child: Text(
                                'DEMO DATA — NOT GOVERNMENT DATA',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileCard() {
    final b = _beneficiary!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppConstants.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppConstants.primaryNavy,
                  child: Text(
                    b.nameForDemo.substring(0, 1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.nameForDemo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppConstants.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppConstants.secondaryNavy
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              b.pseudonymousBeneficiaryId,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: AppConstants.secondaryNavy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              b.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.storefront_outlined,
                    size: 18, color: AppConstants.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT REGISTERED FAIR PRICE SHOP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${b.registeredFpsId} — ${b.registeredFpsName ?? "Home FPS Center"}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.accentBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.event_available_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPCOMING DISTRIBUTION ALLOCATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cycle 7 — September 2026 (2026-09)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppConstants.accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppConstants.accentAmber),
            ),
            child: Text(
              'OPEN FOR INTENT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppConstants.accentAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommodityEntitlements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MONTHLY ENTITLEMENTS (COMMODITY QUOTA)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppConstants.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuotaCard(
                'Rice (Fortified)',
                '25.0 kg',
                '₹3.00 / kg (Subsidized)',
                Icons.grain_rounded,
                AppConstants.primaryNavy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuotaCard(
                'Wheat (Whole Grain)',
                '10.0 kg',
                '₹2.00 / kg (Subsidized)',
                Icons.bakery_dining_rounded,
                AppConstants.accentAmber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuotaCard(String commodity, String quantity, String price,
      IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppConstants.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  commodity,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.primaryNavy,
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quantity,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              price,
              style: TextStyle(
                fontSize: 10,
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanningIntentCtaCard() {
    final hasDeclared = _activeIntents.isNotEmpty;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasDeclared ? AppConstants.successGreen : AppConstants.accentBlue,
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasDeclared
                            ? AppConstants.successGreen
                            : AppConstants.accentBlue)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasDeclared
                        ? Icons.check_circle_outline
                        : Icons.alt_route_rounded,
                    color: hasDeclared
                        ? AppConstants.successGreen
                        : AppConstants.accentBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasDeclared
                            ? 'Upcoming Collection Planned'
                            : 'Plan your upcoming collection',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppConstants.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasDeclared
                            ? 'You have already submitted a forward-looking intent. You can update it anytime before dispatch lock.'
                            : 'Tell the supply chain where you intend to pick up your ration in Cycle 7 to prevent stockouts.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _navigateToIntentSelection,
              icon: Icon(
                hasDeclared ? Icons.edit_location_alt_outlined : Icons.touch_app_outlined,
                size: 20,
              ),
              label: Text(
                hasDeclared ? 'Update Intended FPS' : 'Select Intended FPS',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasDeclared
                    ? AppConstants.secondaryNavy
                    : AppConstants.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveIntentsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppConstants.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ACTIVE INTENT SIGNALS (CYCLE 7)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.primaryNavy,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'RECORDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._activeIntents.map((intent) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.bgLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppConstants.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      intent.commodity == 'Rice'
                          ? Icons.grain
                          : Icons.bakery_dining,
                      color: AppConstants.primaryNavy,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${intent.commodity}: ${intent.declaredQuantityKg} kg → ${intent.intendedFpsId}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (intent.isPortabilityIntent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppConstants.accentAmber
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PORTABILITY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppConstants.accentAmber,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryQuickLink() {
    return OutlinedButton.icon(
      onPressed: _navigateToIntentHistory,
      icon: const Icon(Icons.history, size: 18),
      label: const Text('View All Intent History'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppConstants.primaryNavy,
        side: BorderSide(color: AppConstants.cardBorder),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
