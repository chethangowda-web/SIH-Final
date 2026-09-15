import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';

class FpsOwnerDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const FpsOwnerDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<FpsOwnerDashboardScreen> createState() => _FpsOwnerDashboardScreenState();
}

class _FpsOwnerDashboardScreenState extends State<FpsOwnerDashboardScreen> {
  late final ApiService _apiService;
  int _activeTab = 0; // 0: Current Stock, 1: Digital Register, 2: e-PoS Screen
  bool _isLoading = true;

  // Selected FPS
  String _selectedFpsId = 'FPS-KA-BAG-0001';
  String _selectedFpsName = 'Malleshwaram Fair Price Shop #1';
  List<FpsShop> _fpsList = [];

  // Current Stock State
  double _riceStockKg = 1500.0;
  double _wheatStockKg = 400.0;
  double _sugarStockKg = 120.0;
  double _keroseneStockL = 90.0;

  // Digital Register State
  List<Map<String, dynamic>> _digitalRegister = [];

  // e-PoS State
  final TextEditingController _cardSearchController = TextEditingController(text: 'RC-KA-000001');
  bool _isSearching = false;
  Map<String, dynamic>? _searchedBeneficiary;
  bool _isBiometricVerified = false;
  bool _isDispensing = false;
  double _dispenseRiceKg = 10.0;
  double _dispenseWheatKg = 2.0;

  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _amber = Color(0xFFD97706);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    if (widget.username != null && widget.username!.startsWith('FPS-')) {
      _selectedFpsId = widget.username!;
    }
    _loadAllFpsData();
  }

  @override
  void dispose() {
    _cardSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllFpsData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch FPS list
      try {
        final list = await _apiService.fetchFPSList();
        if (list.isNotEmpty) {
          _fpsList = list;
          final current = _fpsList.firstWhere(
            (f) => f.fpsId == _selectedFpsId,
            orElse: () => _fpsList.first,
          );
          _selectedFpsId = current.fpsId;
          _selectedFpsName = current.name;
        }
      } catch (_) {}

      // 2. Load live inventory
      await _loadInventory();

      // 3. Load digital register transactions
      await _loadTransactions();

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInventory() async {
    try {
      final inv = await _apiService.fetchFpsInventory(_selectedFpsId);
      if (mounted) {
        setState(() {
          _riceStockKg = (inv['rice_stock_kg'] as num?)?.toDouble() ?? _riceStockKg;
          _wheatStockKg = (inv['wheat_stock_kg'] as num?)?.toDouble() ?? _wheatStockKg;
          _sugarStockKg = (inv['sugar_stock_kg'] as num?)?.toDouble() ?? _sugarStockKg;
          _keroseneStockL = (inv['kerosene_stock_l'] as num?)?.toDouble() ?? _keroseneStockL;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTransactions() async {
    try {
      final txs = await _apiService.fetchFpsTransactions(_selectedFpsId);
      if (mounted) {
        setState(() {
          _digitalRegister = txs.map((t) => Map<String, dynamic>.from(t as Map)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSearchBeneficiary() async {
    final query = _cardSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchedBeneficiary = null;
      _isBiometricVerified = false;
    });

    try {
      // 1. Authoritative check via e-PoS eligibility API
      try {
        final el = await _apiService.checkEposEligibility(
          fpsId: _selectedFpsId,
          beneficiaryId: query,
        );
        if (!mounted) return;
        final rKg = (el['statutory_rice_kg'] as num?)?.toDouble() ?? 0.0;
        final wKg = (el['statutory_wheat_kg'] as num?)?.toDouble() ?? 0.0;
        setState(() {
          _searchedBeneficiary = {
            'cardId': el['beneficiary_id'],
            'name': el['name'],
            'members': el['family_members_count'] ?? 1,
            'cardCategory': el['category_label'] ?? 'Priority Household (BPHH)',
            'riceEntitlementKg': rKg,
            'wheatEntitlementKg': wKg,
            'alreadyCollected': el['already_collected'] == true,
            'collectedAt': el['collected_at'],
            'isPortability': el['is_portability'] == true,
            'homeFps': el['registered_fps_name'] ?? 'Home FPS',
          };
          _dispenseRiceKg = rKg;
          _dispenseWheatKg = wKg;
        });
        return;
      } catch (_) {}

      // 2. Direct search from master beneficiaries dataset
      final beneficiaries = await _apiService.fetchBeneficiaries(search: query, limit: 1);
      if (!mounted) return;

      if (beneficiaries.isNotEmpty) {
        final b = beneficiaries.first;
        final scheme = b.schemeType ?? 'PHH';
        final catLabel = scheme == 'AAY'
            ? 'Antyodaya Anna Yojana (AAY)'
            : 'Priority Household (BPHH / PHH)';
        final rKg = (b.monthlyRiceKg != null && b.monthlyRiceKg! > 0)
            ? b.monthlyRiceKg!
            : (scheme == 'AAY' ? 30.0 : ((b.membersCount ?? 4) * 4.0));
        final wKg = (b.monthlyWheatKg != null && b.monthlyWheatKg! > 0)
            ? b.monthlyWheatKg!
            : (scheme == 'AAY' ? 5.0 : ((b.membersCount ?? 4) * 1.0));

        setState(() {
          _searchedBeneficiary = {
            'cardId': b.pseudonymousBeneficiaryId,
            'name': b.nameForDemo,
            'members': b.membersCount ?? 4,
            'cardCategory': catLabel,
            'riceEntitlementKg': rKg,
            'wheatEntitlementKg': wKg,
            'alreadyCollected': false,
            'isPortability': b.registeredFpsId != _selectedFpsId,
            'homeFps': b.registeredFpsName ?? b.registeredFpsId,
          };
          _dispenseRiceKg = rKg;
          _dispenseWheatKg = wKg;
        });
      } else {
        // Fallback for search query
        setState(() {
          _searchedBeneficiary = {
            'cardId': query,
            'name': 'Citizen ($query)',
            'members': 4,
            'cardCategory': 'Priority Household (BPHH)',
            'riceEntitlementKg': 20.0,
            'wheatEntitlementKg': 5.0,
            'alreadyCollected': false,
          };
          _dispenseRiceKg = 20.0;
          _dispenseWheatKg = 5.0;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchedBeneficiary = {
            'cardId': query,
            'name': 'Citizen ($query)',
            'members': 4,
            'cardCategory': 'BPHH',
            'riceEntitlementKg': 20.0,
            'wheatEntitlementKg': 5.0,
            'alreadyCollected': false,
          };
          _dispenseRiceKg = 20.0;
          _dispenseWheatKg = 5.0;
        });
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _handleDispenseRation() async {
    if (_searchedBeneficiary == null) return;
    final cardId = _searchedBeneficiary!['cardId'] as String;

    setState(() => _isDispensing = true);
    try {
      final res = await _apiService.dispenseEposRation(
        fpsId: _selectedFpsId,
        beneficiaryId: cardId,
        riceKg: _dispenseRiceKg,
        wheatKg: _dispenseWheatKg,
        authMode: 'AADHAAR_BIOMETRIC_FINGERPRINT',
      );

      if (!mounted) return;
      setState(() {
        _isDispensing = false;
        _searchedBeneficiary!['alreadyCollected'] = true;
      });

      // Reload inventory & transactions
      await _loadInventory();
      await _loadTransactions();

      final txId = res['transaction_id'] ?? 'TX-EPOS-OK';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _govGreen, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text('e-PoS Ration Dispensed & Sealed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaction recorded in digital register and deducted from inventory.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transaction ID:', style: TextStyle(fontSize: 12, color: _slate500)),
                        Text(txId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _slate900)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Beneficiary:', style: TextStyle(fontSize: 12, color: _slate500)),
                        Text(cardId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _slate900)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fortified Rice:', style: TextStyle(fontSize: 12, color: _slate500)),
                        Text('${_dispenseRiceKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _govGreen)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Whole Wheat:', style: TextStyle(fontSize: 12, color: _slate500)),
                        Text('${_dispenseWheatKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _govGreen)),
                      ],
                    ),
                    const Divider(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Citizen Charge:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('₹0.00 (NFSA 100% Free)', style: TextStyle(fontWeight: FontWeight.w800, color: _govGreen)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _govNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Done & Print Slip'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDispensing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('e-PoS Dispensation Failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _govNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FPS Owner Operations Portal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Fair Price Shop: $_selectedFpsId • $_selectedFpsName',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
        actions: [
          // Real FPS Switcher (Allows testing different shops from dataset)
          if (_fpsList.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Switch Fair Price Shop',
              onSelected: (fpsId) {
                final selected = _fpsList.firstWhere((f) => f.fpsId == fpsId);
                setState(() {
                  _selectedFpsId = selected.fpsId;
                  _selectedFpsName = selected.name;
                });
                _loadInventory();
                _loadTransactions();
              },
              itemBuilder: (context) => _fpsList.take(20).map<PopupMenuEntry<String>>((fps) {
                return PopupMenuItem<String>(
                  value: fps.fpsId,
                  child: Text('${fps.fpsId} - ${fps.name}', style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF4ADE80)),
                SizedBox(width: 6),
                Text('e-PoS Terminal Online', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 3 Sub-Navigation Tabs matching user's architecture diagram
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: _slate200)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildTabButton(0, '📦 Current Stock', Icons.inventory_2_outlined),
                      const SizedBox(width: 8),
                      _buildTabButton(1, '📖 Digital Register', Icons.receipt_long_outlined),
                      const SizedBox(width: 8),
                      _buildTabButton(2, '📱 e-PoS Screen', Icons.point_of_sale_rounded),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      _buildCurrentStockView(),
                      _buildDigitalRegisterView(),
                      _buildEposScreenView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _govNavy : _slate100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : _slate500),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : _slate700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: CURRENT STOCK (Responsive and clean layout)
  // =========================================================================
  Widget _buildCurrentStockView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ration Shop Physical Stock Ledger', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  Text('Live inventory for $_selectedFpsId • Reconciled with central warehouse', style: const TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Stock',
                onPressed: _loadInventory,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stock Commodity Grid (Clean cards with proper heights)
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 2.2 : 1.8,
              children: [
                _buildStockCard('Fortified Rice', '${_riceStockKg.toStringAsFixed(0)} kg', 'Safe Buffer (>500kg)', Icons.rice_bowl, _govGreen, const Color(0xFFF0FDF4)),
                _buildStockCard('Whole Wheat', '${_wheatStockKg.toStringAsFixed(0)} kg', 'Safe Buffer (>200kg)', Icons.grain, _amber, const Color(0xFFFFFBEB)),
                _buildStockCard('Refined Sugar', '${_sugarStockKg.toStringAsFixed(0)} kg', 'Adequate Stock', Icons.cake_outlined, const Color(0xFF6B21A8), const Color(0xFFF3E8FF)),
                _buildStockCard('Kerosene Fuel', '${_keroseneStockL.toStringAsFixed(0)} L', 'Reservoir Normal', Icons.local_gas_station, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Central Depot Incoming Replenishment Tracker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, color: _govNavy, size: 20),
                    SizedBox(width: 8),
                    Text('Incoming Depot Replenishment Tracking (Phase 14A Route)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildReplenishmentRow('Truck KA-04-GA-9081 (Driver: Ramesh)', '4,500 kg Fortified Rice', 'En Route from Central FCI Godown', 'ETA: 45 Mins'),
                const Divider(),
                _buildReplenishmentRow('Truck KA-04-GA-7712 (Driver: Suresh)', '2,000 kg Whole Wheat Buffer', 'Loading Verified at Bay #2', 'Scheduled Today'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(String title, String qty, String status, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(qty, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _buildReplenishmentRow(String title, String detail, String status, String eta) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text('$detail • $status', style: const TextStyle(fontSize: 11, color: _slate500)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(6)),
          child: Text(eta, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy)),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: DIGITAL REGISTER
  // =========================================================================
  Widget _buildDigitalRegisterView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Digital Grain Dispensation Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  Text('${_digitalRegister.length} Transactions Recorded for Cycle 2026-09', style: const TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Transactions',
                onPressed: _loadTransactions,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _slate200),
              ),
              child: _digitalRegister.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 40, color: _slate500),
                          SizedBox(height: 8),
                          Text('No transactions recorded yet in this cycle.', style: TextStyle(color: _slate500, fontSize: 13)),
                          Text('Use the e-PoS Screen tab to dispense rations to beneficiaries.', style: TextStyle(color: _slate500, fontSize: 11)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _digitalRegister.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final tx = _digitalRegister[idx];
                        final rice = (tx['rice_kg'] as num?)?.toDouble() ?? 0.0;
                        final wheat = (tx['wheat_kg'] as num?)?.toDouble() ?? 0.0;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFF0FDF4),
                            radius: 16,
                            child: const Icon(Icons.fingerprint_rounded, size: 18, color: _govGreen),
                          ),
                          title: Row(
                            children: [
                              Text(
                                tx['beneficiary_id'] ?? 'BEN-KA-0000',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tx['name_for_demo'] ?? tx['name'] ?? 'Citizen Holder',
                                style: const TextStyle(fontSize: 12, color: _slate700),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Rice: ${rice.toStringAsFixed(1)} kg • Wheat: ${wheat.toStringAsFixed(1)} kg • Auth: ${tx['auth_mode'] ?? "Aadhaar Biometric"}',
                            style: const TextStyle(fontSize: 11, color: _slate500),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('DISPENSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                              ),
                              const SizedBox(height: 2),
                              Text(tx['created_at'] ?? 'Today', style: const TextStyle(fontSize: 10, color: _slate500)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: e-PoS SCREEN (Dispensation Terminal)
  // =========================================================================
  Widget _buildEposScreenView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('e-PoS Biometric Ration Dispensation Terminal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
          const Text('Select or search citizen Ration Card Number to verify statutory quota and authorize grain release.', style: TextStyle(fontSize: 12, color: _slate500)),
          const SizedBox(height: 16),

          // Search Box
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardSearchController,
                  decoration: InputDecoration(
                    hintText: 'Enter Ration Card ID (e.g. RC-KA-000001 or BEN-KA-0001)...',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.credit_card_rounded, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                  ),
                  onSubmitted: (_) => _handleSearchBeneficiary(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSearching ? null : _handleSearchBeneficiary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSearching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Lookup Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Beneficiary Details Card
          if (_searchedBeneficiary != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_box_rounded, color: _govNavy, size: 24),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_searchedBeneficiary!['name'] ?? 'Citizen Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Card: ${_searchedBeneficiary!['cardId']} • ${_searchedBeneficiary!['cardCategory']}', style: const TextStyle(fontSize: 11, color: _slate500)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_searchedBeneficiary!['isPortability'] == true) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF93C5FD)),
                              ),
                              child: const Text('ONORC PORTABLE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_searchedBeneficiary!['alreadyCollected'] as bool) ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: (_searchedBeneficiary!['alreadyCollected'] as bool) ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                            ),
                            child: Text(
                              (_searchedBeneficiary!['alreadyCollected'] as bool) ? 'ALREADY COLLECTED' : 'ELIGIBLE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (_searchedBeneficiary!['alreadyCollected'] as bool) ? const Color(0xFFDC2626) : _govGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Statutory Quota Rows
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fortified Rice Entitlement', style: TextStyle(fontSize: 11, color: _govGreen, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${_dispenseRiceKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _govGreen)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Whole Wheat Entitlement', style: TextStyle(fontSize: 11, color: _amber, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${_dispenseWheatKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _amber)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Biometric Authentication Step
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _slate100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _slate200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isBiometricVerified ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                              size: 24,
                              color: _isBiometricVerified ? _govGreen : _slate700,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Aadhaar Biometric e-KYC Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(
                                  _isBiometricVerified ? 'Identity Verified: Match 98.6%' : 'Place citizen finger on scanner',
                                  style: TextStyle(fontSize: 10.5, color: _isBiometricVerified ? _govGreen : _slate500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() => _isBiometricVerified = !_isBiometricVerified),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isBiometricVerified ? _govGreen : _govNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          child: Text(_isBiometricVerified ? 'Verified ✓' : 'Scan Fingerprint', style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dispense Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: (_isBiometricVerified && !_isDispensing && !(_searchedBeneficiary!['alreadyCollected'] as bool))
                          ? _handleDispenseRation
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _govGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isDispensing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              (_searchedBeneficiary!['alreadyCollected'] as bool)
                                  ? 'RATION ALREADY COLLECTED FOR CYCLE 2026-09'
                                  : 'AUTHORIZE & DISPENSE RATION (${_dispenseRiceKg.toStringAsFixed(0)}kg Rice + ${_dispenseWheatKg.toStringAsFixed(0)}kg Wheat)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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
}
