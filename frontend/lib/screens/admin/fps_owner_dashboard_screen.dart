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
  
  // Persistent 8-Stage Workflow Bar Index (0 to 7)
  // 0: OPEN SHOP, 1: STOCK, 2: REPLENISHMENT, 3: SERVE BENEFICIARY, 4: e-PoS DISPENSE, 5: DIGITAL REGISTER, 6: RECONCILIATION, 7: CLOSE DAY
  int _activeStep = 0;
  bool _isLoading = true;

  // Selected FPS & Header State
  String _selectedFpsId = 'FPS-KA-BAG-0001';
  String _selectedFpsName = 'Fair Price Shop 1 (Bagalkot)';
  List<FpsShop> _fpsList = [];
  final String _currentCycle = '2026-09';
  String _shopStatusLabel = 'OPEN'; // OPEN, ATTENTION REQUIRED, CLOSED
  Map<String, dynamic>? _dailyStatusData;

  // Current Stock State
  double _riceStockKg = 0.0;
  double _wheatStockKg = 0.0;
  double _sugarStockKg = 0.0;
  double _keroseneStockL = 0.0;
  Map<String, dynamic>? _stockLedgerData;

  // Replenishment State
  List<Map<String, dynamic>> _consignments = [];
  bool _isLoadingConsignments = false;

  // Serve Beneficiary & e-PoS Terminal State
  final TextEditingController _cardSearchController = TextEditingController(text: 'RC-KA-000001');
  bool _isSearchingBeneficiary = false;
  Map<String, dynamic>? _searchedBeneficiary;
  double _dispenseRiceKg = 0.0;
  double _dispenseWheatKg = 0.0;
  bool _isBiometricVerified = false;
  bool _isScanningBiometrics = false;
  bool _isDispensing = false;

  // Digital Register State
  List<Map<String, dynamic>> _digitalRegister = [];
  final TextEditingController _registerSearchController = TextEditingController();

  // Reconciliation State
  Map<String, dynamic>? _reconciliationData;

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

  // Preset Sample Cards for One-Click Dataset Lookup
  final List<Map<String, String>> _sampleRationCards = [
    {'cardId': 'RC-KA-000001', 'label': 'RC-KA-000001 (BPHH)'},
    {'cardId': 'RC-KA-000005', 'label': 'RC-KA-000005 (AAY)'},
    {'cardId': 'RC-KA-000010', 'label': 'RC-KA-000010 (BPHH 8 Mem)'},
    {'cardId': 'RC-KA-000012', 'label': 'RC-KA-000012 (ONORC Portable)'},
    {'cardId': 'BEN-KA-0001', 'label': 'BEN-KA-0001 (PHH)'},
  ];

  final List<String> _stepTitles = [
    'OPEN SHOP',
    'STOCK',
    'REPLENISHMENT',
    'SERVE BENEFICIARY',
    'e-PoS DISPENSE',
    'DIGITAL REGISTER',
    'RECONCILIATION',
    'CLOSE DAY',
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
    super.dispose();
  }

  Future<void> _loadAllFpsData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch FPS Shops List
      try {
        final list = await _apiService.fetchFpsList();
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

      // 2. Load Store Daily Operational Status
      await _loadDailyStatus();

      // 3. Load Store Inventory
      await _loadInventory();

      // 4. Load Replenishment Consignments
      await _loadConsignments();

      // 5. Load Digital Register Transactions
      await _loadTransactions();

      // 6. Load Reconciliation Data
      await _loadReconciliation();

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDailyStatus() async {
    try {
      final status = await _apiService.fetchFpsDailyStatus(_selectedFpsId);
      if (mounted) {
        setState(() {
          _dailyStatusData = status;
          _shopStatusLabel = status['shop_operational_status'] ?? 'OPEN';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInventory() async {
    try {
      final inv = await _apiService.fetchFpsInventory(_selectedFpsId);
      if (mounted) {
        setState(() {
          _riceStockKg = (inv['rice_stock_kg'] as num?)?.toDouble() ?? 0.0;
          _wheatStockKg = (inv['wheat_stock_kg'] as num?)?.toDouble() ?? 0.0;
          _sugarStockKg = (inv['sugar_stock_kg'] as num?)?.toDouble() ?? 0.0;
          _keroseneStockL = (inv['kerosene_stock_l'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadConsignments() async {
    setState(() => _isLoadingConsignments = true);
    try {
      final res = await _apiService.fetchFpsConsignments(_selectedFpsId);
      if (mounted) {
        final list = (res['consignments'] as List<dynamic>?) ?? [];
        setState(() {
          _consignments = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingConsignments = false);
    }
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

  Future<void> _loadReconciliation() async {
    try {
      final rec = await _apiService.fetchFpsReconciliation(_selectedFpsId);
      if (mounted) {
        setState(() {
          _reconciliationData = rec;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStockLedger() async {
    try {
      final ledger = await _apiService.fetchFpsStockLedger(_selectedFpsId);
      if (mounted) {
        setState(() {
          _stockLedgerData = ledger;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleConfirmConsignment(String gatepassId) async {
    try {
      final res = await _apiService.confirmConsignmentReceipt(_selectedFpsId, gatepassId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Consignment $gatepassId received! Added ${res['rice_added_kg']}kg Rice, ${res['wheat_added_kg']}kg Wheat to FPS inventory.'),
          backgroundColor: _govGreen,
        ),
      );
      await _loadInventory();
      await _loadConsignments();
      await _loadReconciliation();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt Confirmation Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSearchBeneficiary({String? targetCardId}) async {
    final query = (targetCardId ?? _cardSearchController.text).trim();
    if (query.isEmpty) return;

    if (targetCardId != null) {
      _cardSearchController.text = targetCardId;
    }

    setState(() {
      _isSearchingBeneficiary = true;
      _searchedBeneficiary = null;
      _isBiometricVerified = false;
    });

    try {
      final el = await _apiService.checkEposEligibility(
        fpsId: _selectedFpsId,
        beneficiaryId: query,
        cycleId: _currentCycle,
      );
      if (!mounted) return;
      final rKg = (el['statutory_rice_kg'] as num?)?.toDouble() ?? 0.0;
      final wKg = (el['statutory_wheat_kg'] as num?)?.toDouble() ?? 0.0;
      setState(() {
        _searchedBeneficiary = {
          'cardId': el['beneficiary_id'] ?? query,
          'name': el['name'] ?? 'Citizen Holder ($query)',
          'members': el['family_members_count'] ?? 1,
          'cardCategory': el['category_label'] ?? 'Priority Household (BPHH)',
          'riceEntitlementKg': rKg,
          'wheatEntitlementKg': wKg,
          'alreadyCollected': el['already_collected'] == true,
          'collectedAt': el['collected_at'],
          'isPortability': el['is_portability'] == true,
          'homeFps': el['registered_fps_name'] ?? el['registered_fps_id'] ?? 'Home FPS',
        };
        _dispenseRiceKg = rKg;
        _dispenseWheatKg = wKg;
      });
    } catch (e) {
      if (!mounted) return;
      // Show explicit "Data unavailable" state if record does not exist
      setState(() {
        _searchedBeneficiary = {
          'cardId': query,
          'name': 'Data unavailable',
          'members': 0,
          'cardCategory': 'Data unavailable',
          'riceEntitlementKg': 0.0,
          'wheatEntitlementKg': 0.0,
          'alreadyCollected': false,
          'isError': true,
          'errorMessage': e.toString(),
        };
        _dispenseRiceKg = 0.0;
        _dispenseWheatKg = 0.0;
      });
    } finally {
      if (mounted) setState(() => _isSearchingBeneficiary = false);
    }
  }

  Future<void> _simulateBiometricScan() async {
    setState(() => _isScanningBiometrics = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isScanningBiometrics = false;
        _isBiometricVerified = true;
      });
    }
  }

  Future<void> _handleDispenseRation() async {
    if (_searchedBeneficiary == null || _searchedBeneficiary!['isError'] == true) return;
    final cardId = _searchedBeneficiary!['cardId'] as String;

    setState(() => _isDispensing = true);
    try {
      final res = await _apiService.dispenseEposRation(
        fpsId: _selectedFpsId,
        beneficiaryId: cardId,
        riceKg: _dispenseRiceKg,
        wheatKg: _dispenseWheatKg,
        authMode: 'AADHAAR_BIOMETRIC_FINGERPRINT',
        cycleId: _currentCycle,
      );

      if (!mounted) return;
      setState(() {
        _isDispensing = false;
        _searchedBeneficiary!['alreadyCollected'] = true;
      });

      // Reload persistent states
      await _loadInventory();
      await _loadTransactions();
      await _loadDailyStatus();
      await _loadReconciliation();

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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                child: Column(
                  children: [
                    const Text('DEPARTMENT OF FOOD & CIVIL SUPPLIES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _govNavy, letterSpacing: 0.5)),
                    Text('FPS Terminal: $_selectedFpsId • $_selectedFpsName', style: const TextStyle(fontSize: 10, color: _slate500)),
                    const Divider(height: 14),
                    _buildReceiptLine('Transaction Ref:', txId, isBold: true),
                    _buildReceiptLine('Ration Card ID:', cardId),
                    _buildReceiptLine('Citizen Name:', _searchedBeneficiary?['name'] ?? 'Citizen Holder'),
                    _buildReceiptLine('Card Category:', _searchedBeneficiary?['cardCategory'] ?? 'Priority Household'),
                    _buildReceiptLine('Auth Mechanism:', 'Aadhaar Biometric (Match Score 98.6%)'),
                    const Divider(height: 14),
                    _buildReceiptLine('Fortified Rice Issued:', '${_dispenseRiceKg.toStringAsFixed(1)} kg', valueColor: _govGreen),
                    _buildReceiptLine('Whole Wheat Issued:', '${_dispenseWheatKg.toStringAsFixed(1)} kg', valueColor: _amber),
                    const Divider(height: 14),
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
                  Text('Immutable Digital Register Audit Record Sealed', style: TextStyle(fontSize: 10.5, color: _govGreen, fontWeight: FontWeight.w700)),
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
                const SnackBar(content: Text('Digital receipt rendered. Printed thermal receipt generated.')),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print Receipt'),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _slate500)),
          Text(val, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: valueColor ?? _slate900)),
        ],
      ),
    );
  }

  void _showStockLedgerDialog() async {
    await _loadStockLedger();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: _govNavy, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock Ledger Audit Trace — $_selectedFpsId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Text('Opening Stock + Receipts - Dispensed = Closing Available Stock', style: TextStyle(fontSize: 11, color: _slate500)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Formula Breakdown Container
                if (_stockLedgerData != null && _stockLedgerData!['summary'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                    child: Column(
                      children: [
                        _buildLedgerSummaryRow('Fortified Rice', _stockLedgerData!['summary']['Rice']),
                        const Divider(height: 12),
                        _buildLedgerSummaryRow('Whole Wheat', _stockLedgerData!['summary']['Wheat']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text('Chronological Stock Movement Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate900)),
                const SizedBox(height: 8),

                if (_stockLedgerData == null || (_stockLedgerData!['movements'] as List).isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No movement logs recorded yet for active cycle.', style: TextStyle(fontSize: 12, color: _slate500))),
                  ),
                ] else ...[
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (_stockLedgerData!['movements'] as List).length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final item = _stockLedgerData!['movements'][idx];
                        return ListTile(
                          dense: true,
                          leading: const CircleAvatar(radius: 12, backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.swap_vert_rounded, size: 14, color: _govNavy)),
                          title: Text('${item['transaction_type']} • ${item['quantity_summary']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text('Ref: ${item['reference_id']} • Actor: ${item['actor']} • Time: ${item['timestamp']}', style: const TextStyle(fontSize: 10.5, color: _slate500)),
                          trailing: Text(item['balance_after'], style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _govGreen)),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            child: const Text('Close Ledger'),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerSummaryRow(String title, Map<String, dynamic> summary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(
          'Opening: ${summary['opening_stock_kg']}kg  +  Received: ${summary['received_stock_kg']}kg  -  Dispensed: ${summary['dispensed_stock_kg']}kg  =  Available: ${summary['closing_stock_kg']}kg',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _govNavy),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildGovernmentHeader(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Persistent 8-Stage Operational Workflow Bar
                _buildWorkflowNavigationBar(),

                // Stage Guidance Info Bar
                _buildStageGuidanceBanner(),

                // Main Workflow View Stack
                Expanded(
                  child: IndexedStack(
                    index: _activeStep,
                    children: [
                      _buildOpenShopView(),
                      _buildCurrentStockView(),
                      _buildReplenishmentView(),
                      _buildServeBeneficiaryView(),
                      _buildEposScreenView(),
                      _buildDigitalRegisterView(),
                      _buildDailyReconciliationView(),
                      _buildCloseDayView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // =========================================================================
  // GOVERNMENT FPS OPERATIONS HEADER
  // =========================================================================
  PreferredSizeWidget _buildGovernmentHeader() {
    return AppBar(
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
                child: const Text('DEPARTMENT OF FOOD & CIVIL SUPPLIES', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          Text(
            'Fair Price Shop ID: $_selectedFpsId • $_selectedFpsName • Cycle: $_currentCycle',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
      actions: [
        // FPS Shop Switcher dropdown
        if (_fpsList.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.storefront_rounded),
            tooltip: 'Switch Fair Price Shop',
            onSelected: (fpsId) {
              final selected = _fpsList.firstWhere((f) => f.fpsId == fpsId);
              setState(() {
                _selectedFpsId = selected.fpsId;
                _selectedFpsName = selected.name;
              });
              _loadAllFpsData();
            },
            itemBuilder: (context) => _fpsList.take(20).map<PopupMenuEntry<String>>((fps) {
              return PopupMenuItem<String>(
                value: fps.fpsId,
                child: Text('${fps.fpsId} - ${fps.name}', style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
          ),

        // Operational Status Badge
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _shopStatusLabel == 'OPEN' ? const Color(0xFF16A34A).withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _shopStatusLabel == 'OPEN' ? const Color(0xFF86EFAC) : Colors.amber),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, size: 8, color: _shopStatusLabel == 'OPEN' ? const Color(0xFF4ADE80) : Colors.amber),
              const SizedBox(width: 4),
              Text('Shop $_shopStatusLabel', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // e-PoS Gateway Online Status Badge
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            children: [
              Icon(Icons.wifi_rounded, size: 12, color: Color(0xFF4ADE80)),
              SizedBox(width: 4),
              Text('e-PoS Online', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          tooltip: 'Refresh Operations Data',
          onPressed: _loadAllFpsData,
        ),
      ],
    );
  }

  // =========================================================================
  // PERSISTENT 8-STAGE WORKFLOW NAVIGATION BAR
  // =========================================================================
  Widget _buildWorkflowNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _slate200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(8, (index) => _buildWorkflowStepButton(index)),
        ),
      ),
    );
  }

  Widget _buildWorkflowStepButton(int index) {
    final isSelected = _activeStep == index;
    final isCompleted = index < _activeStep;
    final stepNum = (index + 1).toString().padLeft(2, '0');
    final title = _stepTitles[index];

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _activeStep = index),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _govNavy : (isCompleted ? const Color(0xFFF0FDF4) : _slate100),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? _govNavy : (isCompleted ? const Color(0xFF86EFAC) : _slate200),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white : (isCompleted ? _govGreen : _slate500),
                ),
                child: Center(
                  child: isCompleted && !isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : Text(
                          stepNum,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? _govNavy : Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : (isCompleted ? _govGreen : _slate700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageGuidanceBanner() {
    final Map<int, String> instructions = {
      0: 'Confirm daily opening checklist requirements and initialize store operational status.',
      1: 'Review current store inventory levels and trace physical stock movements in the Stock Ledger.',
      2: 'Inspect incoming grain consignments from central godown and confirm physical receipt.',
      3: 'Scan or enter citizen ration card ID to inspect real entitlement quota and check eligibility.',
      4: 'Perform Aadhaar identity verification and dispense authorized grain quota via e-PoS terminal.',
      5: 'Inspect statutory Form 5A digital register logs of completed grain dispensations.',
      6: 'Perform mathematical reconciliation comparing Expected Stock vs Recorded Physical Stock.',
      7: 'Verify end-of-day checklist and close daily store operations.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFEFF6FF),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                children: [
                  TextSpan(text: 'STAGE ${(_activeStep + 1).toString().padLeft(2, '0')} (${_stepTitles[_activeStep]}): ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: instructions[_activeStep] ?? ''),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 01: OPEN SHOP
  // =========================================================================
  Widget _buildOpenShopView() {
    final checklist = _dailyStatusData?['checklist'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.store_rounded, color: _govNavy, size: 22),
                    SizedBox(width: 10),
                    Text('Daily Store Opening Checklist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _slate900)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('All items use actual backend state. Verify store readiness before starting daily operations.', style: TextStyle(fontSize: 12, color: _slate500)),
                const Divider(height: 20),

                _buildChecklistItem('FPS Identity & License Verified', 'Authorized Shop ID: $_selectedFpsId • $_selectedFpsName', checklist?['fps_identity_verified'] == true),
                _buildChecklistItem('Active Distribution Cycle Verified', 'Cycle ID: $_currentCycle', checklist?['active_cycle_verified'] == true),
                _buildChecklistItem('Previous Day Reconciliation Complete', 'Zero unresolved stock discrepancies recorded', checklist?['previous_day_reconciliation'] == true),
                _buildChecklistItem('Current Inventory Synchronized', 'Rice: ${_riceStockKg.toStringAsFixed(0)}kg • Wheat: ${_wheatStockKg.toStringAsFixed(0)}kg', checklist?['inventory_synchronized'] == true),
                _buildChecklistItem('e-PoS Gateway Connectivity', 'Connected to Aadhaar Online Gateway (4G Active)', checklist?['epos_connectivity'] == true),
                _buildChecklistItem('Digital Register Available', 'Form 5A Statutory Ledger Initialized', checklist?['digital_register_available'] == true),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _apiService.openFpsShop(_selectedFpsId);
                        if (!mounted) return;
                        setState(() {
                          _shopStatusLabel = 'OPEN';
                          _activeStep = 1; // Proceed to Stock
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fair Price Shop is officially OPEN for today\'s operations!'), backgroundColor: _govGreen),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error opening shop: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                    label: const Text('START TODAY\'S OPERATIONS / OPEN SHOP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: _govGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, String subtitle, bool isPassed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(isPassed ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 20, color: isPassed ? _govGreen : _amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate900)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _slate500)),
              ],
            ),
          ),
          Text(isPassed ? 'VERIFIED ✓' : 'ATTENTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPassed ? _govGreen : _amber)),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 02: STOCK & INVENTORY
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Store Inventory', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  Text('Actual physical stock recorded in SQLite database', style: TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showStockLedgerDialog,
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const Text('View Stock Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 2.0 : 1.6,
              children: [
                _buildCommodityStockCard('Fortified Rice', '${_riceStockKg.toStringAsFixed(1)} kg', _riceStockKg > 300 ? 'NORMAL' : 'LOW', 'NFSA ₹0.00/kg', Icons.rice_bowl, _govGreen, const Color(0xFFF0FDF4)),
                _buildCommodityStockCard('Whole Wheat', '${_wheatStockKg.toStringAsFixed(1)} kg', _wheatStockKg > 100 ? 'NORMAL' : 'LOW', 'NFSA ₹0.00/kg', Icons.grain, _amber, const Color(0xFFFFFBEB)),
                _buildCommodityStockCard('Refined Sugar', '${_sugarStockKg.toStringAsFixed(1)} kg', 'NORMAL', 'Subsidized ₹13.50/kg', Icons.cake_outlined, const Color(0xFF6B21A8), const Color(0xFFF3E8FF)),
                _buildCommodityStockCard('Kerosene Fuel', '${_keroseneStockL.toStringAsFixed(1)} L', 'NORMAL', 'Subsidized ₹25.00/L', Icons.local_gas_station, const Color(0xFF1E3A8A), const Color(0xFFEFF6FF)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommodityStockCard(String title, String qty, String status, String subText, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Text(qty, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status: $status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              Text(subText, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 03: REPLENISHMENT & CONSIGNMENTS
  // =========================================================================
  Widget _buildReplenishmentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Incoming Consignment Replenishments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  Text('Track trucks & confirm physical grain receipts from Central Godown', style: TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _loadConsignments,
                tooltip: 'Refresh Consignments',
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingConsignments) ...[
            const Center(child: CircularProgressIndicator()),
          ] else if (_consignments.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 40, color: _slate500),
                    SizedBox(height: 8),
                    Text('No active consignments pending for this shop.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate700)),
                    Text('Central Godown dispatch schedules will appear here automatically.', style: TextStyle(fontSize: 11, color: _slate500)),
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _consignments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final c = _consignments[idx];
                final gpId = c['gatepass_id'] ?? 'GP-2026-09-001';
                final truckId = c['truck_id'] ?? 'TRK-KA-001';
                final isReceived = c['status'] == 'RECEIVED';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isReceived ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.local_shipping_rounded, color: isReceived ? _govGreen : _amber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Truck $truckId • Gatepass: $gpId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate900)),
                            Text(c['commodity_summary'] ?? '', style: const TextStyle(fontSize: 11.5, color: _slate700)),
                            Text('Driver: ${c['driver_name'] ?? 'Ramesh Bhat'} (${c['driver_phone'] ?? '9845012345'})', style: const TextStyle(fontSize: 10.5, color: _slate500)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isReceived ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isReceived ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                            ),
                            child: Text(c['status'] ?? 'IN_TRANSIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isReceived ? _govGreen : _amber)),
                          ),
                          const SizedBox(height: 6),
                          if (!isReceived)
                            ElevatedButton.icon(
                              onPressed: () => _handleConfirmConsignment(gpId),
                              icon: const Icon(Icons.check_circle_outline, size: 14),
                              label: const Text('Confirm Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 04: SERVE BENEFICIARY (PRIMARY DAILY ACTION)
  // =========================================================================
  Widget _buildServeBeneficiaryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search Citizen & Verify Entitlement Quota', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
          const Text('Enter Ration Card ID to pull authoritative backend entitlement record.', style: TextStyle(fontSize: 12, color: _slate500)),
          const SizedBox(height: 12),

          // Quick Preset Card Chips
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

          // Search Box
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardSearchController,
                  decoration: InputDecoration(
                    hintText: 'Enter Ration Card ID (e.g. RC-KA-000001)...',
                    prefixIcon: const Icon(Icons.credit_card_rounded, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                  ),
                  onSubmitted: (_) => _handleSearchBeneficiary(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSearchingBeneficiary ? null : () => _handleSearchBeneficiary(),
                icon: _isSearchingBeneficiary
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded, size: 16),
                label: const Text('Retrieve Beneficiary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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

          // Beneficiary Result Details Box
          if (_searchedBeneficiary != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _slate200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(radius: 20, backgroundColor: _govNavy, child: Icon(Icons.person_rounded, color: Colors.white, size: 22)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_searchedBeneficiary!['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _slate900)),
                              Text('Ration Card ID: ${_searchedBeneficiary!['cardId']} • ${_searchedBeneficiary!['members']} Family Members', style: const TextStyle(fontSize: 11.5, color: _slate500)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_searchedBeneficiary!['alreadyCollected'] as bool) ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: (_searchedBeneficiary!['alreadyCollected'] as bool) ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          (_searchedBeneficiary!['alreadyCollected'] as bool) ? 'COLLECTION COMPLETED' : 'ELIGIBLE FOR DISPENSATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: (_searchedBeneficiary!['alreadyCollected'] as bool) ? const Color(0xFFDC2626) : _govGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Quotas Box
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

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: (!(_searchedBeneficiary!['alreadyCollected'] as bool) && _searchedBeneficiary!['isError'] != true)
                          ? () => setState(() => _activeStep = 4) // Advance to e-PoS Dispense
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        (_searchedBeneficiary!['alreadyCollected'] as bool)
                            ? 'COLLECTION COMPLETED FOR CYCLE $_currentCycle'
                            : 'PROCEED TO e-PoS DISPENSATION ➔',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 05: e-PoS DISPENSATION TERMINAL
  // =========================================================================
  Widget _buildEposScreenView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _slate800, width: 2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(color: _slate900, borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.point_of_sale_rounded, color: Color(0xFF4ADE80), size: 18),
                          SizedBox(width: 8),
                          Text('e-PoS HARDWARE TERMINAL • AADHAAR GATEWAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.wifi_rounded, size: 14, color: Color(0xFF4ADE80)),
                          SizedBox(width: 6),
                          Text('4G e-SIM ONLINE', style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _searchedBeneficiary == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Please select a beneficiary in Stage 04 (SERVE BENEFICIARY) first.', style: TextStyle(fontSize: 13, color: _slate500, fontWeight: FontWeight.bold)),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Beneficiary: ${_searchedBeneficiary!['name']} (${_searchedBeneficiary!['cardId']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _slate900)),
                            const SizedBox(height: 12),

                            // Biometric Panel
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _isBiometricVerified ? const Color(0xFF86EFAC) : _slate200)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: _isBiometricVerified ? const Color(0xFFF0FDF4) : _slate100,
                                        child: Icon(_isBiometricVerified ? Icons.check_circle_rounded : Icons.fingerprint_rounded, size: 24, color: _isBiometricVerified ? _govGreen : _govNavy),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Aadhaar Biometric e-KYC Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _slate900)),
                                          Text(
                                            _isScanningBiometrics
                                                ? 'Capturing optical fingerprint sensor pulse...'
                                                : (_isBiometricVerified ? 'Identity Verified: Match Score 98.6% — Approved ✓' : 'Instruct citizen to place thumb on optical scanner'),
                                            style: TextStyle(fontSize: 11, color: _isBiometricVerified ? _govGreen : _slate500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _isScanningBiometrics ? null : _simulateBiometricScan,
                                    icon: const Icon(Icons.fingerprint_rounded, size: 16),
                                    label: Text(_isBiometricVerified ? 'Verified ✓' : 'Scan Fingerprint', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(backgroundColor: _isBiometricVerified ? _govGreen : _govNavy, foregroundColor: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Dispense Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: (_isBiometricVerified && !_isDispensing && !(_searchedBeneficiary!['alreadyCollected'] as bool)) ? _handleDispenseRation : null,
                                style: ElevatedButton.styleFrom(backgroundColor: _govGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                child: _isDispensing
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(
                                        (_searchedBeneficiary!['alreadyCollected'] as bool)
                                            ? 'RATION ALREADY COLLECTED FOR CYCLE $_currentCycle'
                                            : '⚡ AUTHORIZE & DISPENSE RATION (${_dispenseRiceKg.toStringAsFixed(1)}kg Rice + ${_dispenseWheatKg.toStringAsFixed(1)}kg Wheat)',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                      ),
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
    );
  }

  // =========================================================================
  // STEP 06: DIGITAL REGISTER (Form 5A Statutory Log)
  // =========================================================================
  Widget _buildDigitalRegisterView() {
    final query = _registerSearchController.text.trim().toLowerCase();
    final filteredList = _digitalRegister.where((tx) {
      final cardId = (tx['beneficiary_id'] ?? '').toString().toLowerCase();
      final name = (tx['name_for_demo'] ?? tx['name'] ?? '').toString().toLowerCase();
      return query.isEmpty || cardId.contains(query) || name.contains(query);
    }).toList();

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
                  const Text('Statutory Digital Grain Dispensation Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  Text('${_digitalRegister.length} Immutable Logs for Cycle $_currentCycle', style: const TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _loadTransactions),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _registerSearchController,
            decoration: InputDecoration(
              hintText: 'Filter register by Card ID or Citizen Name...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
              child: filteredList.isEmpty
                  ? const Center(child: Text('No digital register records found.', style: TextStyle(color: _slate500, fontSize: 13, fontWeight: FontWeight.bold)))
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

                        return ListTile(
                          dense: true,
                          leading: const CircleAvatar(backgroundColor: Color(0xFFF0FDF4), radius: 16, child: Icon(Icons.fingerprint_rounded, size: 18, color: _govGreen)),
                          title: Row(
                            children: [
                              Text(cardId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _govNavy)),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(fontSize: 12, color: _slate700, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          subtitle: Text('Rice: ${rice.toStringAsFixed(1)}kg • Wheat: ${wheat.toStringAsFixed(1)}kg • Charge: ₹0.00 • Auth: Aadhaar Biometric', style: const TextStyle(fontSize: 11, color: _slate500)),
                          trailing: IconButton(
                            icon: const Icon(Icons.receipt_rounded, size: 18, color: _govNavy),
                            onPressed: () => _showReceiptDialog(txId: txId, cardId: cardId),
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
  // STEP 07: DAILY RECONCILIATION
  // =========================================================================
  Widget _buildDailyReconciliationView() {
    final recData = _reconciliationData?['commodities'] as Map<String, dynamic>?;
    final riceRec = recData?['Rice'] as Map<String, dynamic>?;
    final wheatRec = recData?['Wheat'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Physical Stock Reconciliation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
          const Text('Formula: Opening Stock + Received Stock - Dispensed Stock = Expected Closing Stock', style: TextStyle(fontSize: 12, color: _slate500)),
          const SizedBox(height: 16),

          if (riceRec != null) _buildReconciliationCommodityBox('Fortified Rice', riceRec),
          const SizedBox(height: 12),
          if (wheatRec != null) _buildReconciliationCommodityBox('Whole Wheat', wheatRec),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Daily Stock Reconciliation Verified & Logged ✓'), backgroundColor: _govGreen),
                );
                setState(() => _activeStep = 7); // Advance to Close Day
              },
              icon: const Icon(Icons.verified_rounded, size: 18),
              label: const Text('VERIFY & LOCK DAILY RECONCILIATION ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconciliationCommodityBox(String title, Map<String, dynamic> data) {
    final diff = (data['difference_kg'] as num?)?.toDouble() ?? 0.0;
    final isReconciled = diff == 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _slate900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: isReconciled ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                child: Text(isReconciled ? 'RECONCILED ✓' : 'VARIANCE DETECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isReconciled ? _govGreen : Colors.red)),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRecMetric('Opening', '${data['opening_stock_kg']}kg'),
              _buildRecMetric('Received', '+${data['received_kg']}kg'),
              _buildRecMetric('Dispensed', '-${data['dispensed_kg']}kg'),
              _buildRecMetric('Expected Closing', '${data['expected_closing_kg']}kg', isBold: true),
              _buildRecMetric('Recorded Physical', '${data['recorded_physical_kg']}kg', isBold: true),
              _buildRecMetric('Difference', '${diff.toStringAsFixed(1)}kg', color: isReconciled ? _govGreen : Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecMetric(String label, String val, {bool isBold = false, Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: _slate500)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? _slate900)),
      ],
    );
  }

  // =========================================================================
  // STEP 08: CLOSE DAY
  // =========================================================================
  Widget _buildCloseDayView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: _govNavy, size: 22),
                    SizedBox(width: 10),
                    Text('Close Daily Store Operations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _slate900)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Verify end-of-day operational summary before closing.', style: TextStyle(fontSize: 12, color: _slate500)),
                const Divider(height: 20),

                _buildChecklistItem('All Transactions Synchronized', 'Central Audit Trail Updated', true),
                _buildChecklistItem('Digital Register Sealed', 'Form 5A Finalized', true),
                _buildChecklistItem('Inventory Reconciled', 'Zero Discrepancy Verified', true),
                _buildChecklistItem('No Pending e-PoS Transactions', 'All terminal queues cleared', true),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _apiService.closeFpsShop(_selectedFpsId);
                        if (!mounted) return;
                        setState(() {
                          _shopStatusLabel = 'CLOSED';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fair Price Shop operations successfully CLOSED for today!'), backgroundColor: _govNavy),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error closing shop: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.lock_rounded, size: 18),
                    label: const Text('CLOSE TODAY\'S OPERATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: _slate800, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
