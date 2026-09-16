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

  // Selected FPS State
  String _selectedFpsId = 'FPS-KA-BAG-0001';
  String _selectedFpsName = 'Malleshwaram Fair Price Shop #1';
  List<FpsShop> _fpsList = [];

  // Current Stock State
  double _riceStockKg = 1500.0;
  double _wheatStockKg = 400.0;
  double _sugarStockKg = 120.0;
  double _keroseneStockL = 90.0;

  // Digital Register State & Filter
  List<Map<String, dynamic>> _digitalRegister = [];
  final TextEditingController _registerSearchController = TextEditingController();
  String _authFilterMode = 'ALL'; // ALL, AADHAAR_BIOMETRIC, IRIS_SCAN

  // e-PoS Terminal State
  final TextEditingController _cardSearchController = TextEditingController(text: 'RC-KA-000001');
  bool _isSearching = false;
  Map<String, dynamic>? _searchedBeneficiary;
  bool _isBiometricVerified = false;
  bool _isScanningBiometrics = false;
  bool _isDispensing = false;
  double _dispenseRiceKg = 20.0;
  double _dispenseWheatKg = 5.0;

  // Indent Form State
  bool _isSubmittingIndent = false;
  final TextEditingController _indentRiceController = TextEditingController(text: '2000');
  final TextEditingController _indentWheatController = TextEditingController(text: '500');

  // Guided Loading Bay Stepper Pipeline State
  int _selectedQueueIndex = 0;
  final List<Map<String, dynamic>> _loadingBayQueue = [
    {
      'truckId': 'TRK-KA-0001',
      'driverName': 'Ramesh Bhat',
      'gatepassId': 'GP-2026-09-0001',
      'bay': 'Bay-02',
      'stage': 1,
      'statusLabel': 'STAGE 1: GATEPASS_ISSUED',
    },
    {
      'truckId': 'TRK-KA-0002',
      'driverName': 'Sanjay Patil',
      'gatepassId': 'GP-2026-09-0002',
      'bay': 'Bay-03',
      'stage': 1,
      'statusLabel': 'STAGE 1: GATEPASS_ISSUED',
    },
    {
      'truckId': 'TRK-KA-0003',
      'driverName': 'Kiran Rao',
      'gatepassId': 'GP-2026-09-0003',
      'bay': 'Bay-04',
      'stage': 1,
      'statusLabel': 'STAGE 1: GATEPASS_ISSUED',
    },
    {
      'truckId': 'TRK-KA-0004',
      'driverName': 'Kiran Kumar',
      'gatepassId': 'GP-2026-09-0004',
      'bay': 'Bay-01',
      'stage': 1,
      'statusLabel': 'STAGE 1: GATEPASS_ISSUED',
    },
    {
      'truckId': 'TRK-KA-0005',
      'driverName': 'Venkatesh Naik',
      'gatepassId': 'GP-2026-09-0005',
      'bay': 'Bay-02',
      'stage': 1,
      'statusLabel': 'STAGE 1: GATEPASS_ISSUED',
    },
    {
      'truckId': 'TRK-KA-0006',
      'driverName': 'Harish Reddy',
      'gatepassId': 'GP-2026-09-0006',
      'bay': 'Bay-03',
      'stage': 1,
      'statusLabel': 'STAGE 1: GATEPASS_ISSUED',
    },
    {
      'truckId': 'TRK-KA-0007',
      'driverName': 'Sanjay Shetty',
      'gatepassId': 'GP-2026-09-0007',
      'bay': 'Bay-04',
      'stage': 1,
      'statusLabel': 'STAGE 1: GATEPASS_ISSUED',
    },
  ];

  // Statutory Design Tokens
  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _amber = Color(0xFFD97706);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate800 = Color(0xFF1E293B);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);

  // Quick Preset Sample Ration Cards for One-Click Testing
  final List<Map<String, String>> _sampleRationCards = [
    {'cardId': 'RC-KA-000001', 'name': 'Suresh Kumar', 'label': 'RC-KA-000001 (BPHH)'},
    {'cardId': 'RC-KA-000005', 'name': 'Lakshmi Amma', 'label': 'RC-KA-000005 (AAY)'},
    {'cardId': 'RC-KA-000012', 'name': 'Ramesh Babu', 'label': 'RC-KA-000012 (ONORC Portable)'},
    {'cardId': 'RC-KA-000020', 'name': 'Devappa Gowda', 'label': 'RC-KA-000020 (BPHH)'},
  ];

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
    _registerSearchController.dispose();
    _indentRiceController.dispose();
    _indentWheatController.dispose();
    super.dispose();
  }

  Future<void> _loadAllFpsData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch FPS Shops List
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

      // 2. Load persistent shop inventory
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

  Future<void> _handleSearchBeneficiary({String? targetCardId}) async {
    final query = (targetCardId ?? _cardSearchController.text).trim();
    if (query.isEmpty) return;

    if (targetCardId != null) {
      _cardSearchController.text = targetCardId;
    }

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

      // 2. Search master beneficiary database
      final beneficiaries = await _apiService.fetchBeneficiaries(search: query, limit: 1);
      if (!mounted) return;

      if (beneficiaries.isNotEmpty) {
        final b = beneficiaries.first;
        final scheme = b.schemeType ?? 'PHH';
        final catLabel = scheme == 'AAY'
            ? 'Antyodaya Anna Yojana (AAY)'
            : 'Priority Household (BPHH)';
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
            'cardCategory': 'Priority Household (BPHH)',
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

  Future<void> _simulateBiometricScan() async {
    setState(() => _isScanningBiometrics = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _isScanningBiometrics = false;
        _isBiometricVerified = true;
      });
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

      // Reload inventory & digital register transactions
      await _loadInventory();
      await _loadTransactions();

      final txId = res['transaction_id'] ?? 'TX-EPOS-OK';

      _showReceiptDialog(txId: txId, cardId: cardId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDispensing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('e-PoS Dispensation Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showReceiptDialog({required String txId, required String cardId}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: _govGreen, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Official e-PoS Transaction Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Issued under NFSA 2013 & PDS Control Order', style: TextStyle(fontSize: 11, color: _slate500)),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          width: 440,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                child: Column(
                  children: [
                    const Text('DEPARTMENT OF FOOD & CIVIL SUPPLIES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _govNavy, letterSpacing: 0.5)),
                    Text('e-PoS Terminal: $_selectedFpsId • $_selectedFpsName', style: const TextStyle(fontSize: 10, color: _slate500)),
                    const Divider(height: 12),
                    _buildReceiptLine('Transaction Ref:', txId, isBold: true),
                    _buildReceiptLine('Ration Card ID:', cardId),
                    _buildReceiptLine('Citizen Name:', _searchedBeneficiary?['name'] ?? 'Suresh Kumar'),
                    _buildReceiptLine('Card Category:', _searchedBeneficiary?['cardCategory'] ?? 'BPHH'),
                    _buildReceiptLine('Auth Mechanism:', 'Aadhaar Biometric (98.6% Match)'),
                    const Divider(height: 12),
                    _buildReceiptLine('Fortified Rice Issued:', '${_dispenseRiceKg.toStringAsFixed(1)} kg', valueColor: _govGreen),
                    _buildReceiptLine('Whole Wheat Issued:', '${_dispenseWheatKg.toStringAsFixed(1)} kg', valueColor: _amber),
                    const Divider(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Charge:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('₹0.00 (NFSA 100% Free)', style: TextStyle(fontWeight: FontWeight.w800, color: _govGreen, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: _govGreen),
                  SizedBox(width: 4),
                  Text('SHA-256 Sealed in Central Government Audit Trail', style: TextStyle(fontSize: 10.5, color: _govGreen, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt sent to citizen mobile & printed on e-PoS thermal printer.')),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print Receipt Slip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptLine(String label, String val, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _slate500)),
          Text(val, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: valueColor ?? _slate900)),
        ],
      ),
    );
  }

  Future<void> _handleSubmitIndent() async {
    setState(() => _isSubmittingIndent = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isSubmittingIndent = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.send_and_archive_rounded, color: _govNavy, size: 24),
            SizedBox(width: 8),
            Text('Stock Indent Requisition Submitted', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Indent request for ${_indentRiceController.text} kg Rice and ${_indentWheatController.text} kg Wheat for cycle 2026-10 has been transmitted to the District Supply Officer (DSO) allocation desk.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
            Row(
              children: [
                const Text(
                  'FPS Owner Operations Portal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(color: Color(0xFF1E3A8A), borderRadius: BorderRadius.all(Radius.circular(4))),
                  child: const Text('KA PDS CONTROL', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
            Text(
              'Fair Price Shop ID: $_selectedFpsId • $_selectedFpsName',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
        actions: [
          // FPS Shop Switcher from dataset
          if (_fpsList.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.storefront_rounded),
              tooltip: 'Switch Fair Price Shop (Real Dataset)',
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
                Text('e-PoS Gateway Online', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Navigation Bar Tabs
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: _slate200)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildTabButton(0, '🚚 Loading Bay Stepper Pipeline', Icons.local_shipping_outlined),
                      const SizedBox(width: 8),
                      _buildTabButton(1, '📱 e-PoS Terminal', Icons.point_of_sale_rounded),
                      const SizedBox(width: 8),
                      _buildTabButton(2, '📦 Stock & Inventory', Icons.inventory_2_outlined),
                      const SizedBox(width: 8),
                      _buildTabButton(3, '📖 Digital Register', Icons.receipt_long_outlined),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      _buildLoadingBayPipelineStepperView(),
                      _buildEposScreenView(),
                      _buildCurrentStockView(),
                      _buildDigitalRegisterView(),
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
  // TAB 0: CURRENT STOCK & PHYSICAL REPLENISHMENT SUITE
  // =========================================================================
  Widget _buildCurrentStockView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Store Status Header Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_govNavy, Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.store_rounded, color: Color(0xFF4ADE80), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'STORE OPERATIONAL • STATUTORY FORM 4B SEAL VERIFIED',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live physical warehouse inventory for $_selectedFpsId • Synchronized with Central FCI Godown',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loadInventory,
                      icon: const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                      label: const Text('Sync Stock', style: TextStyle(color: Colors.white, fontSize: 11)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily Dispensation KPI Summary Row
          Row(
            children: [
              Expanded(child: _buildKpiCard('Cycle Footfall Served', '42 / 120 Cards', '35.0% Month Coverage', Icons.groups_outlined, const Color(0xFF2563EB))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Grain Disbursed Today', '840 kg Rice / 210 kg Wheat', '42 Successful e-PoS Tx', Icons.task_alt_rounded, _govGreen)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('e-PoS Device Status', 'Battery 98% • 4G Airtel', 'Weighing Scale Bluetooth OK', Icons.bluetooth_connected_rounded, _amber)),
            ],
          ),
          const SizedBox(height: 16),

          // Physical Commodities Grid
          const Text('Ration Shop Physical Commodities Inventory', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _slate900)),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 2.1 : 1.7,
              children: [
                _buildStockCard('Fortified Rice (Grade A)', '${_riceStockKg.toStringAsFixed(0)} kg', 'Safe Buffer (>500kg)', 'NFSA ₹0.00/kg', Icons.rice_bowl, _govGreen, const Color(0xFFF0FDF4)),
                _buildStockCard('Whole Wheat', '${_wheatStockKg.toStringAsFixed(0)} kg', 'Safe Buffer (>200kg)', 'NFSA ₹0.00/kg', Icons.grain, _amber, const Color(0xFFFFFBEB)),
                _buildStockCard('Refined Sugar', '${_sugarStockKg.toStringAsFixed(0)} kg', 'Adequate Stock', 'Subsidized ₹13.50/kg', Icons.cake_outlined, const Color(0xFF6B21A8), const Color(0xFFF3E8FF)),
                _buildStockCard('Kerosene Fuel', '${_keroseneStockL.toStringAsFixed(0)} L', 'Reservoir Normal', 'Subsidized ₹25.00/L', Icons.local_gas_station, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
              ],
            );
          }),
          const SizedBox(height: 16),

          // 2-Column Detailed Operational Workspace (Fills layout cleanly)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Replenishment Route Tracking & Physical Calibration
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Incoming Central Godown Replenishment
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.local_shipping_outlined, color: _govNavy, size: 20),
                                  SizedBox(width: 8),
                                  Text('Central FCI Depot Replenishment Tracking (Phase 14A Route)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              Text('LIVE GPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildReplenishmentRow('Truck KA-04-GA-9081 (Driver: Ramesh)', '4,500 kg Fortified Rice', 'En Route from Central FCI Godown', 'ETA: 45 Mins'),
                          const Divider(height: 16),
                          _buildReplenishmentRow('Truck KA-04-GA-7712 (Driver: Suresh)', '2,000 kg Whole Wheat', 'Loading Verified at Bay #2', 'Scheduled Today'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Statutory Inspection Tag & Weighbridge Calibration
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
                              Icon(Icons.verified_user_outlined, color: _govNavy, size: 18),
                              SizedBox(width: 8),
                              Text('Statutory Weighbridge & Shop Compliance Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildComplianceStatusItem('Electronic Weighing Scale Calibration:', 'Tag #LMA-2026-881 (Valid till Dec 2026)', isOK: true),
                          _buildComplianceStatusItem('Mandatory NFSA Price Display Board:', 'Updated Today • 100% Free Grain Scheme Displayed', isOK: true),
                          _buildComplianceStatusItem('CCTV Live Surveillance Monitoring:', 'Operational (3 Cameras Active)', isOK: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right Column: Hardware Diagnostics & Monthly Stock Indent Form
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // e-PoS Hardware Peripheral Diagnostic Panel
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
                              Icon(Icons.hardware_rounded, color: _govNavy, size: 18),
                              SizedBox(width: 8),
                              Text('e-PoS Terminal Hardware Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDiagnosticRow('Aadhaar Optical Scanner:', 'Ready (SDK v3.4)', Icons.fingerprint_rounded, _govGreen),
                          _buildDiagnosticRow('Bluetooth Scale Sync:', 'Paired (Scale #01)', Icons.scale_rounded, _govGreen),
                          _buildDiagnosticRow('Thermal Printer Paper:', 'Paper Level 85%', Icons.print_rounded, _govGreen),
                          _buildDiagnosticRow('Central DB Sync Latency:', '24ms (Instant)', Icons.cloud_done_rounded, _govGreen),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monthly Grain Allocation Indent Generator Form
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
                              Icon(Icons.note_add_outlined, color: _govNavy, size: 18),
                              SizedBox(width: 8),
                              Text('Submit Stock Indent (Cycle 2026-10)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('Request additional allocation quota from District Supply Office.', style: TextStyle(fontSize: 11, color: _slate500)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _indentRiceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Rice Indent (kg)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _indentWheatController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Wheat Indent (kg)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmittingIndent ? null : _handleSubmitIndent,
                              icon: _isSubmittingIndent
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send_rounded, size: 14),
                              label: const Text('Submit Indent to DSO Office', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: _slate500, fontWeight: FontWeight.w600)),
                Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                Text(sub, style: const TextStyle(fontSize: 10, color: _slate500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(String title, String qty, String status, String subText, IconData icon, Color color, Color bg) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              Text(subText, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8))),
            ],
          ),
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

  Widget _buildComplianceStatusItem(String title, String val, {required bool isOK}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(isOK ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 16, color: isOK ? _govGreen : Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11.5, color: _slate900),
                children: [
                  TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: val, style: const TextStyle(color: _slate500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String val, IconData icon, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _slate500),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11.5, color: _slate700)),
            ],
          ),
          Text(val, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: statusColor)),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: STATUTORY DIGITAL REGISTER (Searchable & Filterable)
  // =========================================================================
  Widget _buildDigitalRegisterView() {
    final query = _registerSearchController.text.trim().toLowerCase();
    final filteredList = _digitalRegister.where((tx) {
      final cardId = (tx['beneficiary_id'] ?? '').toString().toLowerCase();
      final name = (tx['name_for_demo'] ?? tx['name'] ?? '').toString().toLowerCase();
      final mode = (tx['auth_mode'] ?? '').toString().toUpperCase();

      final matchesQuery = query.isEmpty || cardId.contains(query) || name.contains(query);
      final matchesMode = _authFilterMode == 'ALL' || mode.contains(_authFilterMode);

      return matchesQuery && matchesMode;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Register Header Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Statutory Digital Grain Dispensation Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  Text('${_digitalRegister.length} Total Dispensation Logs for Active Cycle 2026-09 • Reconciled with Master Ledger', style: const TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Statutory Digital Register (Form 5A CSV) exported.')),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Export Form 5A', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh Register',
                    onPressed: _loadTransactions,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _registerSearchController,
                  decoration: InputDecoration(
                    hintText: 'Filter register by Card ID or Citizen Name...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),

              // Filter Pills
              _buildFilterPill('ALL', 'All Auths'),
              const SizedBox(width: 6),
              _buildFilterPill('AADHAAR', 'Aadhaar Biometric'),
              const SizedBox(width: 6),
              _buildFilterPill('IRIS', 'Iris Scan'),
            ],
          ),
          const SizedBox(height: 12),

          // Transactions List Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _slate200),
              ),
              child: filteredList.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 44, color: _slate500),
                          SizedBox(height: 8),
                          Text('No digital register records match the selected filter.', style: TextStyle(color: _slate500, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('Use the e-PoS Screen tab to perform a live grain dispensation.', style: TextStyle(color: _slate500, fontSize: 11)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final tx = filteredList[idx];
                        final txId = tx['transaction_id'] ?? 'TX-EPOS-${idx + 100}';
                        final cardId = tx['beneficiary_id'] ?? 'BEN-KA-0000';
                        final name = tx['name_for_demo'] ?? tx['name'] ?? 'Citizen Holder';
                        final rice = (tx['rice_kg'] as num?)?.toDouble() ?? 0.0;
                        final wheat = (tx['wheat_kg'] as num?)?.toDouble() ?? 0.0;
                        final authMode = tx['auth_mode'] ?? 'AADHAAR_BIOMETRIC';

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFF0FDF4),
                            radius: 16,
                            child: const Icon(Icons.fingerprint_rounded, size: 18, color: _govGreen),
                          ),
                          title: Row(
                            children: [
                              Text(cardId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _govNavy)),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(fontSize: 12, color: _slate700, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(4)),
                                child: Text(txId, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _slate500)),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Fortified Rice: ${rice.toStringAsFixed(1)} kg • Whole Wheat: ${wheat.toStringAsFixed(1)} kg • Charge: ₹0.00 FREE • Auth: $authMode',
                            style: const TextStyle(fontSize: 11, color: _slate500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                    ),
                                    child: const Text('DISPENSED ✓', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _govGreen)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(tx['created_at'] ?? 'Today', style: const TextStyle(fontSize: 10, color: _slate500)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.receipt_rounded, size: 18, color: _govNavy),
                                tooltip: 'View Full Slip',
                                onPressed: () => _showReceiptDialog(txId: txId, cardId: cardId),
                              ),
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

  Widget _buildFilterPill(String mode, String label) {
    final isSelected = _authFilterMode == mode;
    return InkWell(
      onTap: () => setState(() => _authFilterMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _govNavy : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? _govNavy : _slate200),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : _slate700),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 2: e-PoS BIOMETRIC DISPENSATION TERMINAL (Hardware Screen Frame)
  // =========================================================================
  Widget _buildEposScreenView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // e-PoS Hardware Frame Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _slate800, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hardware Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: _slate900,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.point_of_sale_rounded, color: Color(0xFF4ADE80), size: 18),
                          SizedBox(width: 8),
                          Text('e-PoS HARDWARE TERMINAL v4.2.1 • AADHAAR ONLINE GATEWAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.wifi_rounded, size: 14, color: Color(0xFF4ADE80)),
                          SizedBox(width: 6),
                          Text('4G e-SIM LIVE', style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preset Quick Test Card Chips
                      Row(
                        children: [
                          const Text('Quick Test Preset Cards:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _sampleRationCards.map((preset) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      label: Text(preset['label']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      backgroundColor: _cardSearchController.text == preset['cardId'] ? const Color(0xFFEFF6FF) : _slate100,
                                      side: BorderSide(color: _cardSearchController.text == preset['cardId'] ? const Color(0xFF3B82F6) : _slate200),
                                      onPressed: () => _handleSearchBeneficiary(targetCardId: preset['cardId']),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Ration Card Search Box
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cardSearchController,
                              decoration: InputDecoration(
                                hintText: 'Enter Ration Card ID (e.g. RC-KA-000001 or BEN-KA-0001)...',
                                prefixIcon: const Icon(Icons.credit_card_rounded, size: 18),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                              ),
                              onSubmitted: (_) => _handleSearchBeneficiary(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isSearching ? null : () => _handleSearchBeneficiary(),
                            icon: _isSearching
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.search_rounded, size: 16),
                            label: const Text('Lookup Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _govNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Beneficiary Entitlement Card & Biometric Scanner Panel
                      if (_searchedBeneficiary != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Citizen Header & Status Badges
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: _govNavy,
                                        radius: 18,
                                        child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_searchedBeneficiary!['name'] ?? 'Citizen Name', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _slate900)),
                                          Text('Card ID: ${_searchedBeneficiary!['cardId']} • ${_searchedBeneficiary!['members']} Family Members', style: const TextStyle(fontSize: 11.5, color: _slate500)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (_searchedBeneficiary!['isPortability'] == true) ...[
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF93C5FD)),
                                          ),
                                          child: const Text('ONORC PORTABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                                        ),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (_searchedBeneficiary!['alreadyCollected'] as bool) ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: (_searchedBeneficiary!['alreadyCollected'] as bool) ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                                        ),
                                        child: Text(
                                          (_searchedBeneficiary!['alreadyCollected'] as bool) ? 'ALREADY COLLECTED' : 'ELIGIBLE FOR DISPENSATION',
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

                              // Quota Entitlement Boxes
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF86EFAC))),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Fortified Rice Quota', style: TextStyle(fontSize: 11, color: _govGreen, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text('${_dispenseRiceKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _govGreen)),
                                          const Text('Rate: ₹0.00 / kg (NFSA Free)', style: TextStyle(fontSize: 10, color: _govGreen)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCD34D))),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Whole Wheat Quota', style: TextStyle(fontSize: 11, color: _amber, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text('${_dispenseWheatKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _amber)),
                                          const Text('Rate: ₹0.00 / kg (NFSA Free)', style: TextStyle(fontSize: 10, color: _amber)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Interactive Biometric Optical Scanner Box
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _isBiometricVerified ? const Color(0xFF86EFAC) : _slate200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: _isBiometricVerified ? const Color(0xFFF0FDF4) : _slate100,
                                              child: Icon(
                                                _isBiometricVerified ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                                                size: 26,
                                                color: _isBiometricVerified ? _govGreen : _govNavy,
                                              ),
                                            ),
                                            if (_isScanningBiometrics)
                                              const SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: _govNavy),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Aadhaar Biometric e-KYC Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate900)),
                                            Text(
                                              _isScanningBiometrics
                                                  ? 'Capturing optical fingerprint sensor pulse...'
                                                  : (_isBiometricVerified
                                                      ? 'Identity Verified: Match Score 98.6% — Aadhaar Gateway Approved ✓'
                                                      : 'Instruct citizen to place thumb on e-PoS optical scanner sensor'),
                                              style: TextStyle(fontSize: 11, color: _isBiometricVerified ? _govGreen : _slate500, fontWeight: _isBiometricVerified ? FontWeight.w700 : FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _isScanningBiometrics ? null : _simulateBiometricScan,
                                      icon: const Icon(Icons.fingerprint_rounded, size: 16),
                                      label: Text(_isBiometricVerified ? 'Verified ✓' : 'Scan Fingerprint', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isBiometricVerified ? _govGreen : _govNavy,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Authorize & Dispense Button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: (_isBiometricVerified && !_isDispensing && !(_searchedBeneficiary!['alreadyCollected'] as bool))
                                      ? _handleDispenseRation
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _govGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 2,
                                  ),
                                  child: _isDispensing
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Text(
                                          (_searchedBeneficiary!['alreadyCollected'] as bool)
                                              ? 'RATION ALREADY COLLECTED FOR ACTIVE CYCLE 2026-09'
                                              : '⚡ AUTHORIZE & DISPENSE RATION (${_dispenseRiceKg.toStringAsFixed(0)}kg Rice + ${_dispenseWheatKg.toStringAsFixed(0)}kg Wheat)',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildLoadingBayPipelineStepperView() {
    final selectedTruck = _loadingBayQueue[_selectedQueueIndex.clamp(0, _loadingBayQueue.length - 1)];
    final int stage = selectedTruck['stage'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Authority Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), // Light Cream Amber
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFC2410C), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'PHYSICAL EXECUTION AUTHORITY • GODOWN & LOADING BAY Clearance',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.black, color: Color(0xFFC2410C), letterSpacing: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'On-the-ground physical handshake. Confirms that what was planned in the sealed manifest matches physical truck loading. Policy decisions (Forecast locking & Quota overrides) are restricted to enforce CAG audit separation of duties.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF9A3412), height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📷 Scanning QR Gatepass code... Gatepass GP-2026-09-0001 Verified!'),
                            backgroundColor: Color(0xFFD97706),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                      label: const Text('Scan QR Gatepass', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.lock_outline, size: 14, color: Color(0xFFB45309)),
                      label: const Text('AI Forecast (Restricted)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCD34D)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Digital QR Gatepass Pipeline Stepper Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _slate200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Digital QR Gatepass Pipeline',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _slate900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _slate100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _slate200),
                      ),
                      child: Text(
                        'ACTIVE TRUCK: ${selectedTruck['truckId']}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4 Stepper Circle Nodes
                Row(
                  children: [
                    _buildPipelineStepNode(1, 'Auth', 'Driver Identity', stage >= 1, isCurrent: stage == 1),
                    _buildPipelineStepConnector(stage > 1),
                    _buildPipelineStepNode(2, 'Bay Assign', selectedTruck['bay'] as String, stage >= 2, isCurrent: stage == 2),
                    _buildPipelineStepConnector(stage > 2),
                    _buildPipelineStepNode(3, 'Loading', 'Grain Seal', stage >= 3, isCurrent: stage == 3),
                    _buildPipelineStepConnector(stage > 3),
                    _buildPipelineStepNode(4, 'Exit QR', 'Dispatch Clear', stage >= 4, isCurrent: stage == 4),
                  ],
                ),
                const SizedBox(height: 24),

                // 3 Details Fields
                Row(
                  children: [
                    Expanded(
                      child: _buildPipelineInfoBox(
                        icon: Icons.person_outline,
                        label: 'Driver Name',
                        value: selectedTruck['driverName'] as String,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPipelineInfoBox(
                        icon: Icons.store_outlined,
                        label: 'Assigned Bay',
                        value: selectedTruck['bay'] as String,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPipelineInfoBox(
                        icon: Icons.local_shipping_outlined,
                        label: 'Current Status',
                        value: selectedTruck['statusLabel'] as String,
                        valueColor: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons Bar
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: stage < 4
                          ? () {
                              setState(() {
                                final nextStage = stage + 1;
                                selectedTruck['stage'] = nextStage;
                                if (nextStage == 2) {
                                  selectedTruck['statusLabel'] = 'STAGE 2: BAY_ASSIGNED';
                                } else if (nextStage == 3) {
                                  selectedTruck['statusLabel'] = 'STAGE 3: GRAIN_SEALED';
                                } else if (nextStage == 4) {
                                  selectedTruck['statusLabel'] = 'STAGE 4: DISPATCH_CLEAR';
                                }
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('⏩ Gatepass ${selectedTruck['gatepassId']} advanced to Stage ${selectedTruck['stage']}!'),
                                  backgroundColor: const Color(0xFFD97706),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      label: Text(
                        stage < 4 ? '➔ Advance Gatepass to Stage ${stage + 1}' : '✔ Gatepass Dispatch Cleared',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.verified_rounded, color: _govGreen, size: 24),
                                SizedBox(width: 8),
                                Text('Physical Manifest vs Grain Weight Verified', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: Text(
                              'Verified truck ${selectedTruck['truckId']} physical grain weight (12,500 kg Rice) against sealed DSO manifest ${selectedTruck['gatepassId']}. Zero variance detected.',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.subtitles_outlined, size: 16, color: _slate700),
                      label: const Text('Inspect Physical Manifest vs Grain Weight', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _slate700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _slate200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Godown Loading Bay Dispatch Queue
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Godown Loading Bay Dispatch Queue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _slate900),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Select a truck to inspect physical loading or advance gatepass status',
                  style: TextStyle(fontSize: 12, color: _slate500),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _loadingBayQueue.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = _loadingBayQueue[index];
                    final isSelected = _selectedQueueIndex == index;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedQueueIndex = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFF59E0B) : _slate200,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFDE68A) : _slate100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_shipping_rounded,
                                color: isSelected ? const Color(0xFFD97706) : _slate500,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${t['truckId']} - ${t['driverName']}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF92400E) : _slate900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Gatepass: ${t['gatepassId']} • Bay: ${t['bay']}',
                                    style: const TextStyle(fontSize: 11.5, color: _slate500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                t['statusLabel'] as String,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStepNode(int stepNum, String title, String subtitle, bool isCompleted, {required bool isCurrent}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? const Color(0xFFD97706)
                  : (isCompleted ? const Color(0xFF059669) : Colors.white),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFFB45309)
                    : (isCompleted ? const Color(0xFF059669) : _slate200),
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted && !isCurrent
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : Text(
                      stepNum.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : _slate500,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
              color: isCurrent ? const Color(0xFFD97706) : _slate700,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: _slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStepConnector(bool isCompleted) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 22),
      color: isCompleted ? const Color(0xFF059669) : _slate200,
    );
  }

  Widget _buildPipelineInfoBox({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: valueColor ?? _slate500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: _slate500)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? _slate900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
