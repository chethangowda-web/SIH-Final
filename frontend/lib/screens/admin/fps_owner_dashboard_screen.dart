import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';
import '../beneficiary/demo_login_screen.dart';

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

  bool _isLoading = true;
  bool _isActionLoading = false;
  bool _isDispensing = false;

  // Active Navigation Tab: 0 = Operations Workflow, 1 = Stock, 2 = Beneficiary Service, 3 = e-PoS Transactions, 4 = Digital Register, 5 = Reconciliation, 6 = Reports, 7 = Settings
  int _selectedNavTab = 0;

  // 8-Stage Sequential Workflow Stepper (0 to 7)
  // 0: OPEN SHOP, 1: STOCK, 2: REPLENISHMENT, 3: SERVE BENEFICIARY, 4: e-PoS DISPENSE, 5: DIGITAL REGISTER, 6: RECONCILIATION, 7: CLOSE DAY
  int _activeStep = 0;

  // Selected FPS & Identity State
  String _selectedFpsId = 'FPS-KA-BAG-0001';
  String _selectedFpsName = 'Fair Price Shop 1 (Bagalkot)';
  String _selectedFpsDistrict = 'Bagalkot';
  List<FpsShop> _fpsList = [];
  final String _currentCycle = '2026-09 (Cycle 7)';

  // Operational Session State from Backend
  String _shopOperationalStatus = 'CLOSED'; // OPEN, CLOSED
  String _workflowStatus = 'SHOP_CLOSED';
  String? _openedAt;
  String? _closedAt;
  String? _closureId;
  String? _reconciliationExceptionReason;
  Map<String, dynamic>? _dailyStatusData;

  // Current Stock State
  double _riceStockKg = 0.0;
  double _wheatStockKg = 0.0;
  Map<String, dynamic>? _stockLedgerData;

  // Replenishment State
  List<Map<String, dynamic>> _consignments = [];
  bool _isLoadingConsignments = false;

  // Stage 04 & 05: Serve Beneficiary & e-PoS State
  final TextEditingController _cardSearchController = TextEditingController(text: 'RC-KA-000001');
  bool _isSearchingBeneficiary = false;
  Map<String, dynamic>? _searchedBeneficiary;
  double _dispenseRiceKg = 0.0;
  double _dispenseWheatKg = 0.0;

  // Beneficiary Verification State
  String _verificationMode = 'AADHAAR_BIOMETRIC'; // AADHAAR_BIOMETRIC, OTP
  String _verificationStatus = 'VERIFICATION_REQUIRED'; // VERIFICATION_REQUIRED, VERIFYING, VERIFIED, FAILED
  String? _verifiedTimestamp;
  final TextEditingController _otpCodeController = TextEditingController(text: '123456');

  // Stage 06: Last Digital Receipt State
  Map<String, dynamic>? _lastReceiptData;

  // Digital Register State
  List<Map<String, dynamic>> _digitalRegister = [];
  final TextEditingController _registerSearchController = TextEditingController();
  String _registerDateFilter = 'TODAY'; // TODAY, ALL

  // Reconciliation State
  Map<String, dynamic>? _reconciliationData;
  final TextEditingController _exceptionReasonController = TextEditingController();

  // Statutory Government Design Tokens
  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _govGreenBg = Color(0xFFF0FDF4);
  static const Color _govGreenBorder = Color(0xFF86EFAC);
  static const Color _amberAlert = Color(0xFFD97706);
  static const Color _amberBg = Color(0xFFFFFBEB);
  static const Color _amberBorder = Color(0xFFFDE68A);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _dangerRedBg = Color(0xFFFEF2F2);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate50 = Color(0xFFF8FAFC);

  // Preset Sample Cards for One-Click Dataset Lookup
  final List<Map<String, String>> _sampleRationCards = [
    {'cardId': 'RC-KA-000001', 'label': 'RC-KA-000001 (PHH)'},
    {'cardId': 'RC-KA-000004', 'label': 'RC-KA-000004 (PHH 4 Mem)'},
    {'cardId': 'RC-KA-000005', 'label': 'RC-KA-000005 (AAY)'},
    {'cardId': 'RC-KA-000010', 'label': 'RC-KA-000010 (8 Mem)'},
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
    _otpCodeController.dispose();
    _exceptionReasonController.dispose();
    super.dispose();
  }

  // ================================================================
  // 1. DATA LOADING & BACKEND SESSION PERSISTENCE
  // ================================================================

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
          _selectedFpsDistrict = current.district;
        }
      } catch (_) {}

      // 2. Fetch Persistent Operational Session from Backend
      await _loadOperationalSession();

      // 3. Load Store Daily Operational Status
      await _loadDailyStatus();

      // 4. Load Store Inventory
      await _loadInventory();

      // 5. Load Replenishment Consignments
      await _loadConsignments();

      // 6. Load Digital Register Transactions
      await _loadTransactions();

      // 7. Load Reconciliation Data
      await _loadReconciliation();

      // 8. Load Stock Ledger
      await _loadStockLedger();

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Restore Persistent Daily Operational Session
  Future<void> _loadOperationalSession() async {
    try {
      final sess = await _apiService.fetchFpsOperationalSession(_selectedFpsId);
      if (mounted) {
        setState(() {
          _activeStep = (sess['active_step'] as num?)?.toInt() ?? 0;
          _workflowStatus = sess['workflow_status'] ?? 'SHOP_CLOSED';
          _openedAt = sess['opened_at'];
          _closedAt = sess['closed_at'];
          _closureId = sess['closure_id'];
          _reconciliationExceptionReason = sess['reconciliation_exception_reason'];
          if (_reconciliationExceptionReason != null && _reconciliationExceptionReason!.isNotEmpty) {
            _exceptionReasonController.text = _reconciliationExceptionReason!;
          }

          if (_workflowStatus == 'DAY_CLOSED') {
            _shopOperationalStatus = 'CLOSED';
          } else if (_workflowStatus != 'SHOP_CLOSED') {
            _shopOperationalStatus = 'OPEN';
          } else {
            _shopOperationalStatus = 'CLOSED';
          }

          final sData = (sess['session_data'] as Map<String, dynamic>?) ?? {};
          if (sData['last_receipt'] != null) {
            _lastReceiptData = Map<String, dynamic>.from(sData['last_receipt'] as Map);
          }
        });
      }
    } catch (_) {}
  }

  /// Sync Current Workflow Step & State to Backend
  Future<void> _syncOperationalSession(int step, {String? status}) async {
    try {
      final newStatus = status ?? _workflowStatus;
      final sessionData = {
        'searched_card_id': _cardSearchController.text.trim(),
        'last_receipt': _lastReceiptData,
      };

      await _apiService.saveFpsOperationalSession(
        fpsId: _selectedFpsId,
        activeStep: step,
        workflowStatus: newStatus,
        sessionData: sessionData,
        reconciliationExceptionReason: _exceptionReasonController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _activeStep = step;
          _workflowStatus = newStatus;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDailyStatus() async {
    try {
      final status = await _apiService.fetchFpsDailyStatus(_selectedFpsId);
      if (mounted) {
        setState(() {
          _dailyStatusData = status;
          if (status['shop_operational_status'] != null) {
            _shopOperationalStatus = status['shop_operational_status'];
          }
          if (status['fps_name'] != null) _selectedFpsName = status['fps_name'];
          if (status['district'] != null) _selectedFpsDistrict = status['district'];
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
        });
      }
    } catch (_) {}
  }

  Map<String, dynamic> _getDefaultConsignment() {
    return {
      'gatepass_id': 'GP-2026-09-001',
      'truck_id': 'TRK-KA-0001',
      'truck_plate': 'KA-29-TR-4481',
      'truck_model': 'Eicher Pro 3019 (10 MT Heavy PDS Carrier)',
      'manifest_id': 'MNF-2026-09-001',
      'carrier_name': 'Food Corporation of India (FCI) Contract Logistics',
      'driver_name': 'Ramesh Bhat',
      'driver_phone': '+91-9872907057',
      'driver_license': 'DL-KA-29-2018-004419',
      'source_godown': 'FCI Central Godown (Bagalkot Bay #3)',
      'corridor': 'NH-52 District Arterial Corridor',
      'status': 'ARRIVED_AT_BAY',
      'dispatch_time': '2026-09-17 08:30:00',
      'expected_arrival': 'Today 10:15 AM (On-Time)',
      'rice_kg': 2450.0,
      'rice_bags': 49,
      'wheat_kg': 450.0,
      'wheat_bags': 9,
      'total_payload_kg': 2900.0,
      'total_bags': 58,
      'commodity_summary': 'Fortified Rice: 2,450 kg • Whole Wheat: 450 kg',
      'quantity_kg': 2900.0,
      'moisture_pct': 11.2,
      'gps_seal_status': 'VERIFIED INTACT (SHA-256 #8F2A-09)',
      'current_checkpoint': 'FPS-KA-BAG-0001 Unloading Bay',
      'live_tracking_available': true,
      'current_location': '16.1804° N, 75.6980° E',
    };
  }

  Future<void> _loadConsignments() async {
    setState(() => _isLoadingConsignments = true);
    try {
      final res = await _apiService.fetchFpsConsignments(_selectedFpsId);
      if (mounted) {
        final list = (res['consignments'] as List<dynamic>?) ?? [];
        setState(() {
          if (list.isNotEmpty) {
            _consignments = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          } else {
            _consignments = [_getDefaultConsignment()];
          }
        });
      }
    } catch (_) {
      if (mounted && _consignments.isEmpty) {
        setState(() {
          _consignments = [_getDefaultConsignment()];
        });
      }
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
          if (rec['reconciliation_exception_reason'] != null) {
            _reconciliationExceptionReason = rec['reconciliation_exception_reason'];
            _exceptionReasonController.text = _reconciliationExceptionReason!;
          }
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

  // ================================================================
  // 2. OPERATIONAL ACTIONS (OPEN SHOP, REPLENISH, VERIFY, DISPENSE, CLOSE)
  // ================================================================

  /// Action: Start Today's Operations (Open Shop)
  Future<void> _handleStartOperations() async {
    setState(() => _isActionLoading = true);
    try {
      final res = await _apiService.openFpsShop(_selectedFpsId);
      if (!mounted) return;
      setState(() {
        _shopOperationalStatus = 'OPEN';
        _workflowStatus = 'SHOP_OPENED';
        _openedAt = res['opened_at'] ?? DateTime.now().toString().substring(0, 19);
        _activeStep = 1; // Transition to STOCK
        _isActionLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fair Price Shop is OPEN for today\'s operational cycle.'),
          backgroundColor: _govGreen,
        ),
      );
      await _loadDailyStatus();
      await _syncOperationalSession(1, status: 'STOCK_VERIFIED');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open shop: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  /// Action: Confirm Consignment Receipt
  Future<void> _handleConfirmConsignment(String gatepassId) async {
    final consignment = _consignments.firstWhere(
      (c) => c['gatepass_id'] == gatepassId,
      orElse: () => _getDefaultConsignment(),
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.inventory_rounded, color: _govGreen, size: 24),
            SizedBox(width: 10),
            Text('Acknowledge Physical Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                child: Column(
                  children: [
                    _buildSummaryLine('Carrier Vehicle', '${consignment['truck_plate'] ?? "KA-29-TR-4481"} (${consignment['truck_id'] ?? "TRK-KA-0001"})', isHighlight: true),
                    const Divider(height: 10),
                    _buildSummaryLine('Driver Name & Phone', '${consignment['driver_name'] ?? "Ramesh Bhat"} (${consignment['driver_phone'] ?? "+91-9872907057"})'),
                    const Divider(height: 10),
                    _buildSummaryLine('Gatepass / Manifest ID', '${consignment['gatepass_id']} • ${consignment['manifest_id'] ?? "MNF-2026-09-001"}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('PHYSICAL CARGO RECONCILIATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _slate700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _govGreenBorder)),
                child: Column(
                  children: [
                    _buildSummaryLine('Fortified Rice (NFSA)', '${consignment['rice_kg'] ?? 2450.0} kg (49 × 50kg Bags)'),
                    const Divider(height: 10),
                    _buildSummaryLine('Whole Wheat (NFSA)', '${consignment['wheat_kg'] ?? 450.0} kg (9 × 50kg Bags)'),
                    const Divider(height: 10),
                    _buildSummaryLine('Total Dispatched Gross', '${consignment['quantity_kg'] ?? 2900.0} kg (58 Standard Bags)', isHighlight: true),
                    const Divider(height: 10),
                    _buildSummaryLine('GPS Tamper-Evident E-Seal', 'VERIFIED INTACT (SHA-256 #8F2A-09)'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('By confirming, you attest that physical bag count and weight match the FCI godown manifest and this stock is transferred into FPS store balance.',
                style: TextStyle(fontSize: 11, color: _slate500)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL', style: TextStyle(color: _slate500, fontWeight: FontWeight.bold))),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.verified_rounded, size: 16),
            label: const Text('SIGN & ACCEPT DELIVERY', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: _govGreen, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _apiService.confirmConsignmentReceipt(_selectedFpsId, gatepassId);
      final addedRice = (res['rice_added_kg'] as num?)?.toDouble() ?? (consignment['rice_kg'] as num?)?.toDouble() ?? 2450.0;
      final addedWheat = (res['wheat_added_kg'] as num?)?.toDouble() ?? (consignment['wheat_kg'] as num?)?.toDouble() ?? 450.0;

      if (!mounted) return;
      setState(() {
        _riceStockKg += addedRice;
        _wheatStockKg += addedWheat;
        final idx = _consignments.indexWhere((c) => c['gatepass_id'] == gatepassId);
        if (idx != -1) {
          _consignments[idx]['status'] = 'RECEIVED';
          _consignments[idx]['grn_id'] = 'GRN-2026-09-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
          _consignments[idx]['received_at'] = DateTime.now().toString().split('.')[0];
        }
      });

      _showGrnDialog(gatepassId, consignment, addedRice, addedWheat);

      await _loadInventory();
      await _loadConsignments();
      await _loadReconciliation();
      await _loadStockLedger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt Confirmation: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  void _showGrnDialog(String gatepassId, Map<String, dynamic> c, double rice, double wheat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _govGreen, size: 26),
            SizedBox(width: 10),
            Text('Goods Receipt Note (GRN) Issued', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _govNavy)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _govGreenBorder)),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: _govGreen, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GRN #${c['grn_id'] ?? "GRN-2026-09-00188"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _govGreen)),
                          const Text('Authoritative inventory balance credited in Karnataka Food & Civil Supplies portal.', style: TextStyle(fontSize: 11, color: _slate700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildSummaryLine('Gatepass Reference', gatepassId),
              const Divider(height: 10),
              _buildSummaryLine('Truck Carrier', '${c['truck_plate'] ?? "KA-29-TR-4481"} (${c['truck_id'] ?? "TRK-KA-0001"})'),
              const Divider(height: 10),
              _buildSummaryLine('Fortified Rice Credited', '+${rice.toStringAsFixed(1)} kg'),
              const Divider(height: 10),
              _buildSummaryLine('Whole Wheat Credited', '+${wheat.toStringAsFixed(1)} kg'),
              const Divider(height: 10),
              _buildSummaryLine('New Shop Balance', 'Rice: ${_riceStockKg.toStringAsFixed(1)} kg • Wheat: ${_wheatStockKg.toStringAsFixed(1)} kg', isHighlight: true),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            child: const Text('CLOSE RECEIPT'),
          ),
        ],
      ),
    );
  }

  /// Action: Search Beneficiary Ration Card
  Future<void> _handleSearchBeneficiary({String? targetCardId}) async {
    final query = (targetCardId ?? _cardSearchController.text).trim();
    if (query.isEmpty) return;

    if (targetCardId != null) {
      _cardSearchController.text = targetCardId;
    }

    setState(() {
      _isSearchingBeneficiary = true;
      _searchedBeneficiary = null;
      _verificationStatus = 'VERIFICATION_REQUIRED';
      _verifiedTimestamp = null;
    });

    try {
      final res = await _apiService.checkEposEligibility(
        fpsId: _selectedFpsId,
        beneficiaryId: query,
      );

      if (!mounted) return;
      setState(() {
        _searchedBeneficiary = res;
        _dispenseRiceKg = (res['statutory_rice_kg'] as num?)?.toDouble() ?? 0.0;
        _dispenseWheatKg = (res['statutory_wheat_kg'] as num?)?.toDouble() ?? 0.0;
        _isSearchingBeneficiary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearchingBeneficiary = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beneficiary Lookup Error: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  /// Action: Verify Beneficiary (Biometric or OTP)
  Future<void> _handleVerifyBeneficiary() async {
    if (_searchedBeneficiary == null) return;
    final benId = _searchedBeneficiary!['beneficiary_id'] as String;

    setState(() => _verificationStatus = 'VERIFYING');

    try {
      final res = await _apiService.verifyBeneficiaryEpos(
        fpsId: _selectedFpsId,
        beneficiaryId: benId,
        verificationMode: _verificationMode,
        otpCode: _verificationMode == 'OTP' ? _otpCodeController.text.trim() : null,
      );

      if (!mounted) return;
      setState(() {
        _verificationStatus = 'VERIFIED';
        _verifiedTimestamp = res['verified_at'] ?? DateTime.now().toString().substring(0, 19);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Identity Verified: Beneficiary identity authorized via $_verificationMode.'),
          backgroundColor: _govGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificationStatus = 'FAILED');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification Failed: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  /// Action: Atomic e-PoS Dispensation
  Future<void> _handleDispenseRation() async {
    if (_searchedBeneficiary == null) return;
    if (_verificationStatus != 'VERIFIED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beneficiary must be verified before biometric ration dispensing.'),
          backgroundColor: _amberAlert,
        ),
      );
      return;
    }

    if (_shopOperationalStatus == 'CLOSED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot dispense ration: Fair Price Shop operations are CLOSED today.'),
          backgroundColor: _dangerRed,
        ),
      );
      return;
    }

    final benId = _searchedBeneficiary!['beneficiary_id'] as String;

    setState(() => _isDispensing = true);
    try {
      final res = await _apiService.dispenseEposRation(
        fpsId: _selectedFpsId,
        beneficiaryId: benId,
        riceKg: _dispenseRiceKg,
        wheatKg: _dispenseWheatKg,
        authMode: _verificationMode,
      );

      if (!mounted) return;

      setState(() {
        _lastReceiptData = {
          'transaction_id': res['transaction_id'],
          'beneficiary_id': benId,
          'beneficiary_name': _searchedBeneficiary!['name'] ?? 'Beneficiary',
          'card_type': _searchedBeneficiary!['card_type'] ?? 'PHH',
          'fps_id': _selectedFpsId,
          'cycle_id': res['cycle_id'] ?? '2026-09',
          'rice_kg': _dispenseRiceKg,
          'wheat_kg': _dispenseWheatKg,
          'timestamp': res['receipt_confirmed_at'] ?? DateTime.now().toString().substring(0, 19),
          'auth_mode': _verificationMode,
          'status': 'DISPENSED / COMPLETED',
        };
        _isDispensing = false;
        _activeStep = 5; // Transition to Digital Register / Receipt
      });

      await _loadInventory();
      await _loadTransactions();
      await _loadReconciliation();
      await _loadStockLedger();
      await _syncOperationalSession(5, status: 'REGISTER_UPDATED');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('e-PoS Transaction ${res['transaction_id']} successfully completed & sealed!'),
          backgroundColor: _govGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDispensing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispensation Error: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  /// Action: Close Today's Operations
  Future<void> _handleCloseShop() async {
    // 1. Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: _govNavy, size: 22),
            SizedBox(width: 8),
            Text('Close Today\'s FPS Operations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: const Text(
          'Are you sure you want to close today\'s FPS operations?\n\n'
          'After closure, today\'s operational records will become read-only according to system rules.',
          style: TextStyle(fontSize: 12.5, color: _slate700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: _slate500, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text('CONFIRM & CLOSE DAY', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: _dangerRed, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final res = await _apiService.closeFpsShop(
        _selectedFpsId,
        exceptionReason: _exceptionReasonController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _shopOperationalStatus = 'CLOSED';
        _workflowStatus = 'DAY_CLOSED';
        _closedAt = res['closed_at'] ?? DateTime.now().toString().substring(0, 19);
        _closureId = res['closure_id'] ?? 'CLS-CLOSED';
        _activeStep = 7;
        _isActionLoading = false;
      });

      await _loadDailyStatus();
      await _loadReconciliation();
      await _syncOperationalSession(7, status: 'DAY_CLOSED');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Day closed successfully! Closure ID: ${_closureId ?? ""}'),
          backgroundColor: _govGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Day Closure Failed: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  void _handleResetForNextBeneficiary() {
    setState(() {
      _searchedBeneficiary = null;
      _verificationStatus = 'VERIFICATION_REQUIRED';
      _verifiedTimestamp = null;
      _dispenseRiceKg = 0.0;
      _dispenseWheatKg = 0.0;
      _activeStep = 3; // Return to SERVE BENEFICIARY
    });
    _syncOperationalSession(3, status: 'SERVING');
  }

  void _handleLogout() {
    AuthSession.instance.clear();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DemoLoginScreen()));
  }

  // ================================================================
  // 3. MAIN BUILD WORKSPACE
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // TOP GOVERNMENT HEADER
          _buildGovernmentHeader(),

          // MAIN WORKSTATION BODY
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT NAVIGATION SIDEBAR
                _buildLeftSidebar(),

                // MAIN CONTENT VIEWPORT
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: _govNavy))
                      : _buildActiveContentViewport(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 4. TOP GOVERNMENT HEADER
  // ================================================================
  Widget _buildGovernmentHeader() {
    final isOpen = _shopOperationalStatus == 'OPEN';

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _govNavy,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Emblem & Branding
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                ),
                child: const Icon(Icons.storefront_rounded, color: _govNavy, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'PDS DemandSync',
                        style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF3B82F6), width: 0.8),
                        ),
                        child: const Text('FPS OPERATIONS PORTAL', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(
                    '$_selectedFpsId • $_selectedFpsName • $_selectedFpsDistrict',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Active Cycle Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xFF60A5FA)),
                const SizedBox(width: 5),
                Text(_currentCycle, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Shop Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: isOpen ? _govGreenBg : _dangerRedBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isOpen ? _govGreenBorder : const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                Icon(isOpen ? Icons.door_front_door_rounded : Icons.lock_outline_rounded, size: 12, color: isOpen ? _govGreen : _dangerRed),
                const SizedBox(width: 4),
                Text('SHOP: $_shopOperationalStatus', style: TextStyle(color: isOpen ? _govGreen : _dangerRed, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // e-PoS Gateway Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _govGreenBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _govGreenBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.point_of_sale_rounded, size: 12, color: _govGreen),
                SizedBox(width: 4),
                Text('e-PoS: ONLINE', style: TextStyle(color: _govGreen, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Action Buttons
          IconButton(
            onPressed: _isLoading ? null : _loadAllFpsData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            tooltip: 'Refresh Ledger',
          ),
          IconButton(
            onPressed: _showOperationsHelpDialog,
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 20),
            tooltip: 'Operational Guidelines',
          ),
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 20),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  void _showOperationsHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: _govNavy, size: 22),
            SizedBox(width: 8),
            Text('FPS Operations Statutory Handbook', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fair Price Shop Daily Mandatory SOP:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. Verify inventory opening stock before starting transactions.'),
              SizedBox(height: 4),
              Text('2. Every ration delivery must be authenticated via e-PoS Aadhaar biometric or verified OTP.'),
              SizedBox(height: 4),
              Text('3. Dispensing is locked for beneficiaries who have already collected their monthly quota.'),
              SizedBox(height: 4),
              Text('4. Confirm received warehouse consignments to reconcile inventory.'),
              SizedBox(height: 4),
              Text('5. Perform daily end-of-day reconciliation before executing Close Day.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            child: const Text('UNDERSTOOD'),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 5. LEFT NAVIGATION SIDEBAR
  // ================================================================
  Widget _buildLeftSidebar() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _slate200, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildSidebarItem(0, Icons.assignment_turned_in_rounded, 'Today\'s Operations'),
          _buildSidebarItem(1, Icons.inventory_2_rounded, 'Stock Control'),
          _buildSidebarItem(2, Icons.person_search_rounded, 'Beneficiary Service'),
          _buildSidebarItem(3, Icons.point_of_sale_rounded, 'e-PoS Transactions', count: _digitalRegister.length),
          _buildSidebarItem(4, Icons.menu_book_rounded, 'Digital Register'),
          _buildSidebarItem(5, Icons.balance_rounded, 'Reconciliation'),
          _buildSidebarItem(6, Icons.analytics_outlined, 'Reports'),
          _buildSidebarItem(7, Icons.tune_rounded, 'Settings'),

          const Spacer(),

          // Active Cycle Card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 14, color: _govNavy),
                    SizedBox(width: 6),
                    Text('Active Cycle', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _slate500)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_currentCycle, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: _govNavy)),
                const SizedBox(height: 2),
                Text('Depot: $_selectedFpsId', style: const TextStyle(fontSize: 9.5, color: _slate500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int tabIdx, IconData icon, String label, {int? count}) {
    final isSelected = _selectedNavTab == tabIdx;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedNavTab = tabIdx;
            // When user clicks sidebar items, map directly to relevant operational step if applicable
            if (tabIdx == 0) _activeStep = _activeStep;
            if (tabIdx == 1) _activeStep = 1;
            if (tabIdx == 2) _activeStep = 3;
            if (tabIdx == 3 || tabIdx == 4) _activeStep = 5;
            if (tabIdx == 5) _activeStep = 6;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? _govNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: isSelected ? Colors.white : _slate700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : _slate700,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white24 : _slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : _slate700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // 6. ACTIVE VIEWPORT ROUTING
  // ================================================================
  Widget _buildActiveContentViewport() {
    switch (_selectedNavTab) {
      case 0:
        return _buildOperationsWorkspace();
      case 1:
        return _buildOperationsWorkspace(forcedStep: 1); // Stock
      case 2:
        return _buildOperationsWorkspace(forcedStep: 3); // Serve Beneficiary
      case 3:
      case 4:
        return _buildOperationsWorkspace(forcedStep: 5); // Digital Register
      case 5:
        return _buildOperationsWorkspace(forcedStep: 6); // Reconciliation
      case 6:
        return _buildReportsView();
      case 7:
        return _buildSettingsView();
      default:
        return _buildOperationsWorkspace();
    }
  }

  // ================================================================
  // 7. OPERATIONS WORKSPACE WITH 8-STAGE WORKFLOW
  // ================================================================
  Widget _buildOperationsWorkspace({int? forcedStep}) {
    final stepToRender = forcedStep ?? _activeStep;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 8-STAGE HORIZONTAL WORKFLOW STEPPER
          _buildWorkflowStepper(stepToRender),

          const SizedBox(height: 16),

          // TWO-COLUMN WORKSTATION LAYOUT
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT MAIN COLUMN (Active Step Screen)
              Expanded(
                flex: 7,
                child: _buildCurrentStepContent(stepToRender),
              ),

              const SizedBox(width: 16),

              // RIGHT CONTEXTUAL OPERATIONAL PANEL
              Expanded(
                flex: 4,
                child: _buildRightContextualPanel(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 8. 8-STAGE WORKFLOW STEPPER
  // ================================================================
  Widget _buildWorkflowStepper(int currentStep) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        children: List.generate(_stepTitles.length, (idx) {
          final isCompleted = _workflowStatus == 'DAY_CLOSED' || idx < currentStep;
          final isCurrent = idx == currentStep;
          final isLocked = idx > currentStep && _workflowStatus != 'DAY_CLOSED';
          final isLast = idx == _stepTitles.length - 1;

          Color textColor;
          if (isCompleted) {
            textColor = _govGreen;
          } else if (isCurrent) {
            textColor = _govNavy;
          } else {
            textColor = _slate400;
          }

          return Expanded(
            child: InkWell(
              onTap: () {
                // Strictly sequential: allow clicking only completed steps or current step
                if (idx <= _activeStep || isCompleted) {
                  setState(() {
                    _activeStep = idx;
                  });
                  _syncOperationalSession(idx);
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isCompleted ? _govGreen : (isCurrent ? _govNavy : Colors.transparent),
                                border: Border.all(
                                  color: isCompleted ? _govGreen : (isCurrent ? _govNavy : _slate400),
                                  width: 1.5,
                                ),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: isCompleted
                                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                  : (isLocked
                                      ? const Icon(Icons.lock_outline_rounded, size: 10, color: _slate400)
                                      : Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: isCurrent ? Colors.white : _slate500,
                                          ),
                                        )),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _stepTitles[idx],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 8,
                      height: 1.5,
                      color: isCompleted ? _govGreen : _slate200,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ================================================================
  // 9. DYNAMIC WORKFLOW STEP DISPATCHER
  // ================================================================
  Widget _buildCurrentStepContent(int step) {
    switch (step) {
      case 0:
        return _buildStep01OpenShop();
      case 1:
        return _buildStep02VerifyStock();
      case 2:
        return _buildStep03Replenishment();
      case 3:
        return _buildStep04ServeBeneficiary();
      case 4:
        return _buildStep05EposDispense();
      case 5:
        return _buildStep06DigitalRegisterAndReceipt();
      case 6:
        return _buildStep07DailyReconciliation();
      case 7:
        return _buildStep08CloseDay();
      default:
        return _buildStep01OpenShop();
    }
  }

  // ================================================================
  // STAGE 01 — OPEN SHOP
  // ================================================================
  Widget _buildStep01OpenShop() {
    final isOpen = _shopOperationalStatus == 'OPEN';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.door_front_door_rounded, color: _govNavy, size: 22),
              const SizedBox(width: 8),
              const Text('Stage 01: Daily Shop Opening Verification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOpen ? _govGreenBg : _amberBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isOpen ? _govGreenBorder : _amberBorder),
                ),
                child: Text(
                  isOpen ? 'OPEN' : 'OPENING CHECK PENDING',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isOpen ? _govGreen : _amberAlert),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Verify readiness checklist before accepting beneficiary transactions for today\'s allocation cycle.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          // Readiness Checklist
          _buildChecklistRow('FPS Identity Verification', '$_selectedFpsId — $_selectedFpsName', true),
          _buildChecklistRow('Active Distribution Cycle', _currentCycle, true),
          _buildChecklistRow('Current Operational Date', DateTime.now().toString().substring(0, 10), true),
          _buildChecklistRow('Previous Day Closure & Reconciliation', _closedAt != null ? 'Reconciled (Closed at $_closedAt)' : 'Synchronized with Central Ledger', true),
          _buildChecklistRow('Inventory Synchronization', 'Rice: ${_riceStockKg.toStringAsFixed(0)}kg • Wheat: ${_wheatStockKg.toStringAsFixed(0)}kg', true),
          _buildChecklistRow('e-PoS Terminal Gateway Status', 'ONLINE • Visiontek 92 Terminal Linked', true),
          _buildChecklistRow('Digital Register Availability', '${_digitalRegister.length} persistent transactions registered', true),

          const SizedBox(height: 20),

          // Action Area
          if (!isOpen)
            Center(
              child: ElevatedButton.icon(
                onPressed: _isActionLoading ? null : _handleStartOperations,
                icon: _isActionLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('START TODAY\'S OPERATIONS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _govGreenBorder)),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: _govGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SHOP IS OFFICIALLY OPEN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _govGreen)),
                        Text('Opened at: ${_openedAt ?? "Today 08:00 AM"}. Terminal is authorized to dispense rations.', style: const TextStyle(fontSize: 10.5, color: _slate700)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _activeStep = 1);
                      _syncOperationalSession(1);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text('PROCEED TO STOCK →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: _govGreen, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(String title, String detail, bool verified) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        children: [
          Icon(verified ? Icons.check_circle_rounded : Icons.pending_rounded, color: verified ? _govGreen : _amberAlert, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _slate900)),
                Text(detail, style: const TextStyle(fontSize: 10.5, color: _slate500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(4)),
            child: const Text('VERIFIED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _govGreen)),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STAGE 02 — VERIFY STOCK
  // ================================================================
  Widget _buildStep02VerifyStock() {
    final todayDispensedRice = (_dailyStatusData?['today_summary']?['rice_dispensed_today_kg'] as num?)?.toDouble() ?? 0.0;
    final todayDispensedWheat = (_dailyStatusData?['today_summary']?['wheat_dispensed_today_kg'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: _govNavy, size: 22),
              SizedBox(width: 8),
              Text('Stage 02: Physical & Digital Inventory Control', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Authoritative inventory balance by commodity recorded in the Central Supplies database.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          // Inventory Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _slate200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: _slate50),
                  children: ['COMMODITY', 'CURRENT STOCK', 'DISPENSED TODAY', 'AVAILABLE BALANCE', 'STATUS'].map((h) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(h, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate700)),
                    );
                  }).toList(),
                ),
                _buildCommodityTableRow('Fortified Rice (NFSA)', '${_riceStockKg.toStringAsFixed(1)} kg', '${todayDispensedRice.toStringAsFixed(1)} kg', '${_riceStockKg.toStringAsFixed(1)} kg', _riceStockKg > 300 ? 'ADEQUATE' : 'LOW STOCK'),
                _buildCommodityTableRow('Whole Wheat (NFSA)', '${_wheatStockKg.toStringAsFixed(1)} kg', '${todayDispensedWheat.toStringAsFixed(1)} kg', '${_wheatStockKg.toStringAsFixed(1)} kg', _wheatStockKg > 100 ? 'ADEQUATE' : 'LOW STOCK'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _showStockLedgerDialog,
                icon: const Icon(Icons.menu_book_rounded, size: 14),
                label: const Text('VIEW STOCK LEDGER', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _govNavy),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _activeStep = 2);
                  _syncOperationalSession(2, status: 'REPLENISHMENT_CHECKED');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('CONTINUE TO REPLENISHMENT →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildCommodityTableRow(String name, String current, String dispensed, String available, String status) {
    final isLow = status.contains('LOW');
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(10), child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate900))),
        Padding(padding: const EdgeInsets.all(10), child: Text(current, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _govNavy))),
        Padding(padding: const EdgeInsets.all(10), child: Text(dispensed, style: const TextStyle(fontSize: 11, color: _slate700))),
        Padding(padding: const EdgeInsets.all(10), child: Text(available, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _govGreen))),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isLow ? _amberBg : _govGreenBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isLow ? _amberAlert : _govGreen)),
          ),
        ),
      ],
    );
  }

  void _showStockLedgerDialog() {
    final movements = (_stockLedgerData?['movements'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: _govNavy, size: 20),
            SizedBox(width: 8),
            Text('Official FPS Stock Movement Ledger', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: movements.isEmpty
              ? const Center(child: Text('No stock movements recorded yet.', style: TextStyle(fontSize: 12, color: _slate500)))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: movements.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, idx) {
                    final m = movements[idx];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(m['transaction_type'].toString().contains('Receipt') ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            size: 16, color: m['transaction_type'].toString().contains('Receipt') ? _govGreen : _govNavy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${m['transaction_type']} • ${m['quantity_summary']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text('Ref: ${m['reference_id']} • Actor: ${m['actor']}', style: const TextStyle(fontSize: 10, color: _slate500)),
                            ],
                          ),
                        ),
                        Text(m['timestamp'].toString().substring(0, 16), style: const TextStyle(fontSize: 10, color: _slate400)),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STAGE 03 — REPLENISHMENT
  // ================================================================
  Widget _buildStep03Replenishment() {
    final activeList = _consignments.isNotEmpty ? _consignments : [_getDefaultConsignment()];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.local_shipping_rounded, color: _govNavy, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stage 03: Incoming Consignments & Stock Replenishment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
                    Text('Track carrier fleet dispatch manifests, inspect GPS seal integrity, and accept verified warehouse deliveries.', style: TextStyle(fontSize: 11.5, color: _slate500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (_isLoadingConsignments)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: _govNavy)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, idx) {
                final c = activeList[idx];
                final isReceived = c['status'] == 'RECEIVED';
                final isArrived = c['status'] == 'ARRIVED_AT_BAY' || isReceived;

                return Container(
                  decoration: BoxDecoration(
                    color: isReceived ? const Color(0xFFF8FAFC) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isReceived ? _govGreenBorder : const Color(0xFFCBD5E1), width: isReceived ? 1.5 : 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Top Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isReceived ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                          border: Border(bottom: BorderSide(color: isReceived ? _govGreenBorder : const Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _govNavy, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                c['truck_plate'] ?? 'KA-29-TR-4481',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Fleet ID: ${c['truck_id'] ?? "TRK-KA-0001"} • ${c['truck_model'] ?? "Eicher Pro 3019 (10 MT Carrier)"}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _govNavy),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isReceived
                                    ? _govGreenBg
                                    : (isArrived ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF)),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isReceived ? _govGreenBorder : (isArrived ? _govGreen : const Color(0xFF93C5FD))),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isReceived ? Icons.check_circle : (isArrived ? Icons.location_on : Icons.navigation_rounded),
                                    size: 13,
                                    color: isReceived ? _govGreen : (isArrived ? const Color(0xFF15803D) : const Color(0xFF1D4ED8)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isReceived
                                        ? 'RECEIVED & STOCKED'
                                        : (isArrived ? 'ARRIVED AT UNLOADING BAY' : 'IN TRANSIT (ON-ROUTE)'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: isReceived ? _govGreen : (isArrived ? const Color(0xFF15803D) : const Color(0xFF1D4ED8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Carrier Logistics Details Grid
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('LOGISTICS & DISPATCH METADATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _slate500, letterSpacing: 0.5)),
                                      const SizedBox(height: 8),
                                      _buildReplenishDetail('Source Godown', c['source_godown'] ?? 'FCI Central Godown (Bagalkot Bay #3)'),
                                      _buildReplenishDetail('Transit Corridor', c['corridor'] ?? 'NH-52 District Arterial Corridor'),
                                      _buildReplenishDetail('Gatepass ID', c['gatepass_id'] ?? 'GP-2026-09-001'),
                                      _buildReplenishDetail('Dispatch Manifest', c['manifest_id'] ?? 'MNF-2026-09-001'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('DRIVER & VEHICLE SPECIFICATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _slate500, letterSpacing: 0.5)),
                                      const SizedBox(height: 8),
                                      _buildReplenishDetail('Carrier Operator', c['carrier_name'] ?? 'Food Corporation of India (FCI) Fleet'),
                                      _buildReplenishDetail('Driver Name', '${c['driver_name'] ?? "Ramesh Bhat"} (${c['driver_phone'] ?? "+91-9872907057"})'),
                                      _buildReplenishDetail('Driver License', c['driver_license'] ?? 'DL-KA-29-2018-004419'),
                                      _buildReplenishDetail('Arrival Status', c['expected_arrival'] ?? 'Today 10:15 AM (On-Time)'),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),

                            // Cargo Breakdown Table
                            const Text('DISPATCHED COMMODITY MANIFEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _slate500, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.5),
                                  1: FlexColumnWidth(1.5),
                                  2: FlexColumnWidth(1.5),
                                  3: FlexColumnWidth(1.5),
                                  4: FlexColumnWidth(2),
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                    children: ['COMMODITY', 'DISPATCHED WT', 'BAG COUNT', 'LOT NUMBER', 'STATUTORY SEAL'].map((h) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        child: Text(h, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _slate700)),
                                      );
                                    }).toList(),
                                  ),
                                  TableRow(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text('Fortified Rice (NFSA Grade A)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text('${(c['rice_kg'] ?? 2450.0).toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text('${c['rice_bags'] ?? 49} Bags (50kg)', style: const TextStyle(fontSize: 11)),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text('FCI-BLR-0926-R', style: TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.verified, size: 12, color: _govGreen),
                                            const SizedBox(width: 4),
                                            Text(c['gps_seal_status'] ?? 'INTACT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text('Whole Wheat (NFSA Grain)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text('${(c['wheat_kg'] ?? 450.0).toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text('${c['wheat_bags'] ?? 9} Bags (50kg)', style: const TextStyle(fontSize: 11)),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text('FCI-BLR-0926-W', style: TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.verified, size: 12, color: _govGreen),
                                            const SizedBox(width: 4),
                                            Text(c['gps_seal_status'] ?? 'INTACT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Total and Action Banner
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        'TOTAL GROSS PAYLOAD: ${(c['quantity_kg'] ?? 2900.0).toStringAsFixed(0)} KG (58 BAGS)',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _govNavy),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        'MOISTURE INDEX: ${c['moisture_pct'] ?? 11.2}% (PERMISSIBLE < 14%)',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                                      ),
                                    ),
                                  ],
                                ),

                                if (!isReceived)
                                  ElevatedButton.icon(
                                    onPressed: () => _handleConfirmConsignment(c['gatepass_id'] ?? 'GP-2026-09-001'),
                                    icon: const Icon(Icons.inventory_rounded, size: 16),
                                    label: const Text('ACKNOWLEDGE & ACCEPT WAREHOUSE DELIVERY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _govGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      elevation: 1,
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _govGreenBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _govGreenBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: _govGreen, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'DELIVERY ACCEPTED • GRN #${c['grn_id'] ?? "GRN-2026-09-00188"}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _govGreen),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeStep = 1),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text('BACK TO STOCK', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _slate700),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _activeStep = 3);
                  _syncOperationalSession(3, status: 'SERVING');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('CONTINUE TO BENEFICIARY SERVICE →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplenishDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 11, color: _slate500, fontWeight: FontWeight.w600)),
          ),
          const Text(': ', style: TextStyle(fontSize: 11, color: _slate400)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _govNavy)),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STAGE 04 — SERVE BENEFICIARY
  // ================================================================
  Widget _buildStep04ServeBeneficiary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_search_rounded, color: _govNavy, size: 22),
              SizedBox(width: 8),
              Text('Stage 04: Beneficiary Identification & Entitlement Lookup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Scan or input Ration Card ID to verify statutory entitlement and eligibility for Cycle 2026-09.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          // Search Bar & Sample Chips
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardSearchController,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Ration Card Number / Beneficiary ID',
                    hintText: 'e.g. RC-KA-000001',
                    prefixIcon: const Icon(Icons.credit_card_rounded, color: _govNavy),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isSearchingBeneficiary ? null : () => _handleSearchBeneficiary(),
                icon: _isSearchingBeneficiary
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search_rounded, size: 16),
                label: const Text('SEARCH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quick Preset Chips from Dataset
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _sampleRationCards.map((c) {
              return ActionChip(
                label: Text(c['label']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                backgroundColor: _slate100,
                onPressed: () => _handleSearchBeneficiary(targetCardId: c['cardId']),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Searched Beneficiary Card
          if (_searchedBeneficiary != null) ...[
            _buildBeneficiaryDetailsCard(),
            const SizedBox(height: 18),
            _buildVerificationSection(),
          ] else
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
              child: const Center(
                child: Text('Search a beneficiary ration card above to verify eligibility.', style: TextStyle(fontSize: 12, color: _slate500)),
              ),
            ),

          const SizedBox(height: 20),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeStep = 2),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text('BACK TO REPLENISHMENT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _slate700),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (_searchedBeneficiary != null && _verificationStatus == 'VERIFIED' && _searchedBeneficiary!['already_collected'] != true)
                    ? () {
                        setState(() => _activeStep = 4);
                        _syncOperationalSession(4, status: 'DISPENSING');
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('CONTINUE TO e-PoS DISPENSE →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryDetailsCard() {
    final b = _searchedBeneficiary!;
    final alreadyCollected = b['already_collected'] == true;
    final scheme = b['card_type'] ?? 'PHH';
    final isPortability = b['is_portability'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alreadyCollected ? _dangerRed : _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded, color: _govNavy, size: 20),
                  const SizedBox(width: 8),
                  Text('${b['beneficiary_id']} • ${b['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _govNavy)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: alreadyCollected ? _dangerRedBg : _govGreenBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: alreadyCollected ? const Color(0xFFFCA5A5) : _govGreenBorder),
                ),
                child: Text(
                  alreadyCollected ? 'ALREADY COLLECTED' : 'ELIGIBLE FOR COLLECTION',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: alreadyCollected ? _dangerRed : _govGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Scheme: $scheme • Members: ${b['family_members_count']} • Registered Depot: ${b['registered_fps_id']} ${isPortability ? "(ONORC Portability)" : ""}',
              style: const TextStyle(fontSize: 11, color: _slate500)),
          const Divider(height: 16),

          // Entitlement breakdown
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: _slate200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Statutory Rice Entitlement', style: TextStyle(fontSize: 10, color: _slate500)),
                      Text('${b['statutory_rice_kg']} kg', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: _slate200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Statutory Wheat Entitlement', style: TextStyle(fontSize: 10, color: _slate500)),
                      Text('${b['statutory_wheat_kg']} kg', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (alreadyCollected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _dangerRedBg, borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, size: 16, color: _dangerRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ration already collected for cycle 2026-09 on ${b['collected_at'] ?? "earlier date"}. Duplicate collection is prohibited.',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _dangerRed),
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

  Widget _buildVerificationSection() {
    final isVerified = _verificationStatus == 'VERIFIED';
    final alreadyCollected = _searchedBeneficiary?['already_collected'] == true;

    if (alreadyCollected) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isVerified ? _govGreenBorder : _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Beneficiary Identity Verification (e-KYC / e-PoS):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isVerified ? _govGreenBg : _amberBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _verificationStatus.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: isVerified ? _govGreen : _amberAlert),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              ChoiceChip(
                label: const Text('AADHAAR BIOMETRIC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                selected: _verificationMode == 'AADHAAR_BIOMETRIC',
                selectedColor: _govNavy,
                labelStyle: TextStyle(color: _verificationMode == 'AADHAAR_BIOMETRIC' ? Colors.white : _slate700),
                onSelected: (_) => setState(() => _verificationMode = 'AADHAAR_BIOMETRIC'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('OTP SMS VERIFICATION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                selected: _verificationMode == 'OTP',
                selectedColor: _govNavy,
                labelStyle: TextStyle(color: _verificationMode == 'OTP' ? Colors.white : _slate700),
                onSelected: (_) => setState(() => _verificationMode = 'OTP'),
              ),
            ],
          ),

          if (_verificationMode == 'OTP') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              height: 36,
              child: TextField(
                controller: _otpCodeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Enter 6-Digit OTP',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _verificationStatus == 'VERIFYING' ? null : _handleVerifyBeneficiary,
            icon: _verificationStatus == 'VERIFYING'
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.fingerprint_rounded, size: 16),
            label: Text(isVerified ? 'RE-VERIFY IDENTITY' : 'VERIFY BENEFICIARY IDENTITY', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: isVerified ? _govGreen : _govNavy, foregroundColor: Colors.white),
          ),
          if (isVerified && _verifiedTimestamp != null) ...[
            const SizedBox(height: 6),
            Text('Verified at $_verifiedTimestamp via $_verificationMode', style: const TextStyle(fontSize: 10.5, color: _govGreen, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  // ================================================================
  // STAGE 05 — e-PoS DISPENSE
  // ================================================================
  Widget _buildStep05EposDispense() {
    final b = _searchedBeneficiary;
    if (b == null) {
      return const Center(child: Text('No beneficiary selected for dispensing.'));
    }

    final remRice = _riceStockKg - _dispenseRiceKg;
    final remWheat = _wheatStockKg - _dispenseWheatKg;
    final hasEnoughStock = remRice >= 0 && remWheat >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: _govNavy, size: 22),
              SizedBox(width: 8),
              Text('Stage 05: Final e-PoS Dispensation & Inventory Deduction', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Confirm commodity physical handover and generate immutable government transaction receipt.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          // Dispensing Confirmation Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Beneficiary: ${b['beneficiary_id']} (${b['name']})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _govNavy)),
                    const Text('Cycle: 2026-09', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate700)),
                  ],
                ),
                const Divider(height: 16),

                // Math Table
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: _slate100),
                      children: ['COMMODITY', 'CURRENT WAREHOUSE', 'DISPENSE QUANTITY', 'REMAINING STOCK'].map((h) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(h, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _slate700)),
                        );
                      }).toList(),
                    ),
                    TableRow(
                      children: [
                        const Padding(padding: EdgeInsets.all(8), child: Text('Fortified Rice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${_riceStockKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${_dispenseRiceKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${remRice.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: remRice >= 0 ? _govGreen : _dangerRed))),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Padding(padding: EdgeInsets.all(8), child: Text('Whole Wheat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${_wheatStockKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${_dispenseWheatKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${remWheat.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: remWheat >= 0 ? _govGreen : _dangerRed))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!hasEnoughStock) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _dangerRedBg, borderRadius: BorderRadius.circular(6)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: _dangerRed, size: 18),
                  SizedBox(width: 8),
                  Text('Insufficient warehouse inventory to fulfill full statutory quota.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _dangerRed)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeStep = 3),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text('BACK TO SEARCH', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _slate700),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (_isDispensing || !hasEnoughStock) ? null : _handleDispenseRation,
                icon: _isDispensing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified_rounded, size: 18),
                label: Text(_isDispensing ? 'DISPENSING RATION...' : 'CONFIRM e-PoS TRANSACTION', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(backgroundColor: _govGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STAGE 06 — DIGITAL REGISTER & RECEIPT
  // ================================================================
  Widget _buildStep06DigitalRegisterAndReceipt() {
    final filtered = _digitalRegister.where((tx) {
      final q = _registerSearchController.text.trim().toLowerCase();
      final id = (tx['transaction_id'] ?? '').toString().toLowerCase();
      final ben = (tx['beneficiary_id'] ?? '').toString().toLowerCase();
      final matchesSearch = id.contains(q) || ben.contains(q);
      if (_registerDateFilter == 'TODAY') {
        final date = (tx['created_at'] ?? '').toString();
        final today = DateTime.now().toString().substring(0, 10);
        return matchesSearch && date.startsWith(today);
      }
      return matchesSearch;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: _govNavy, size: 22),
                  SizedBox(width: 8),
                  Text('Stage 06: Digital Register & Issued Receipts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _handleResetForNextBeneficiary,
                icon: const Icon(Icons.person_add_rounded, size: 14),
                label: const Text('SERVE NEXT BENEFICIARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Authoritative transaction ledger of all ration distributions permanently recorded in SQLite.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          // Last Receipt Card if available
          if (_lastReceiptData != null) ...[
            _buildLastReceiptCard(),
            const SizedBox(height: 16),
          ],

          // Filter Controls
          Row(
            children: [
              ChoiceChip(
                label: const Text('TODAY\'S TRANSACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                selected: _registerDateFilter == 'TODAY',
                selectedColor: _govNavy,
                labelStyle: TextStyle(color: _registerDateFilter == 'TODAY' ? Colors.white : _slate700),
                onSelected: (_) => setState(() => _registerDateFilter = 'TODAY'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('ALL TRANSACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                selected: _registerDateFilter == 'ALL',
                selectedColor: _govNavy,
                labelStyle: TextStyle(color: _registerDateFilter == 'ALL' ? Colors.white : _slate700),
                onSelected: (_) => setState(() => _registerDateFilter = 'ALL'),
              ),
              const Spacer(),
              SizedBox(
                width: 200,
                height: 34,
                child: TextField(
                  controller: _registerSearchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: 'Search Card / Transaction...',
                    prefixIcon: Icon(Icons.search_rounded, size: 14),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Digital Register Table
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('No matching transactions found.', style: TextStyle(fontSize: 12, color: _slate500))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final tx = filtered[idx];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _slate50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _slate200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: _govGreen, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${tx['transaction_id']} • Card: ${tx['beneficiary_id']}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govNavy)),
                            Text('Dispensed: ${tx['rice_kg']}kg Rice / ${tx['wheat_kg']}kg Wheat • Auth: ${tx['auth_mode']}', style: const TextStyle(fontSize: 10.5, color: _slate700)),
                          ],
                        ),
                      ),
                      Text(tx['created_at'].toString().substring(0, 16), style: const TextStyle(fontSize: 10, color: _slate400)),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeStep = 4),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text('BACK TO DISPENSE', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _slate700),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _activeStep = 6);
                  _syncOperationalSession(6, status: 'RECONCILIATION_PENDING');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('CONTINUE TO DAILY RECONCILIATION →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastReceiptCard() {
    final r = _lastReceiptData!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _govGreenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _govGreenBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _govGreen, size: 18),
                  SizedBox(width: 6),
                  Text('OFFICIAL DIGITAL RECEIPT ISSUED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _govGreen)),
                ],
              ),
              Text('ID: ${r['transaction_id']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy)),
            ],
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Beneficiary: ${r['beneficiary_name']} (${r['beneficiary_id']})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate900)),
              Text('Handover: ${r['rice_kg']}kg Rice + ${r['wheat_kg']}kg Wheat', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _govNavy)),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STAGE 07 — DAILY RECONCILIATION
  // ================================================================
  Widget _buildStep07DailyReconciliation() {
    final rec = _reconciliationData;
    final rComm = rec?['commodities']?['Rice'] as Map<String, dynamic>?;
    final wComm = rec?['commodities']?['Wheat'] as Map<String, dynamic>?;

    final rDiff = (rComm?['difference_kg'] as num?)?.toDouble() ?? 0.0;
    final wDiff = (wComm?['difference_kg'] as num?)?.toDouble() ?? 0.0;
    final isReconciled = rDiff == 0.0 && wDiff == 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.balance_rounded, color: _govNavy, size: 22),
              const SizedBox(width: 8),
              const Text('Stage 07: Daily Inventory & Transaction Reconciliation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReconciled ? _govGreenBg : _amberBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isReconciled ? _govGreenBorder : _amberBorder),
                ),
                child: Text(
                  isReconciled ? '✓ STOCK RECONCILED' : '⚠ RECONCILIATION EXCEPTION',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isReconciled ? _govGreen : _amberAlert),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Verification Formula: Opening Stock + Received Today - Dispensed Today = Expected Closing Stock.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          // Reconciliation Math Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _slate200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.2),
                5: FlexColumnWidth(1.2),
                6: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: _slate50),
                  children: ['COMMODITY', 'OPENING', '+ RECEIVED', '- DISPENSED', '= EXPECTED', 'RECORDED', 'DIFF'].map((h) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(h, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _slate700)),
                    );
                  }).toList(),
                ),
                _buildReconTableRow('Fortified Rice', rComm),
                _buildReconTableRow('Whole Wheat', wComm),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Exception reason input if variance exists
          if (!isReconciled) ...[
            const Text('Document Reconciliation Exception Reason (Required to close day):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _amberAlert)),
            const SizedBox(height: 6),
            TextField(
              controller: _exceptionReasonController,
              maxLines: 2,
              onChanged: (_) {
                setState(() {});
                _syncOperationalSession(6);
              },
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'e.g. Weighing scale calibration variance of 2.5kg verified against delivery log.',
                filled: true,
                fillColor: _slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeStep = 5),
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text('BACK TO REGISTER', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _slate700),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _activeStep = 7);
                  _syncOperationalSession(7);
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('PROCEED TO CLOSE DAY →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildReconTableRow(String name, Map<String, dynamic>? data) {
    final opening = (data?['opening_stock_kg'] as num?)?.toDouble() ?? 0.0;
    final rec = (data?['received_kg'] as num?)?.toDouble() ?? 0.0;
    final disp = (data?['dispensed_kg'] as num?)?.toDouble() ?? 0.0;
    final exp = (data?['expected_closing_kg'] as num?)?.toDouble() ?? 0.0;
    final recorded = (data?['recorded_physical_kg'] as num?)?.toDouble() ?? 0.0;
    final diff = (data?['difference_kg'] as num?)?.toDouble() ?? 0.0;

    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        Padding(padding: const EdgeInsets.all(8), child: Text('${opening.toStringAsFixed(0)}kg', style: const TextStyle(fontSize: 10.5))),
        Padding(padding: const EdgeInsets.all(8), child: Text('+${rec.toStringAsFixed(0)}kg', style: const TextStyle(fontSize: 10.5, color: _govGreen))),
        Padding(padding: const EdgeInsets.all(8), child: Text('-${disp.toStringAsFixed(0)}kg', style: const TextStyle(fontSize: 10.5, color: _dangerRed))),
        Padding(padding: const EdgeInsets.all(8), child: Text('${exp.toStringAsFixed(0)}kg', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _govNavy))),
        Padding(padding: const EdgeInsets.all(8), child: Text('${recorded.toStringAsFixed(0)}kg', style: const TextStyle(fontSize: 10.5))),
        Padding(padding: const EdgeInsets.all(8), child: Text('${diff >= 0 ? "+$diff" : diff}kg', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: diff == 0 ? _govGreen : _amberAlert))),
      ],
    );
  }

  // ================================================================
  // STAGE 08 — CLOSE DAY
  // ================================================================
  Widget _buildStep08CloseDay() {
    final isDayClosed = _workflowStatus == 'DAY_CLOSED';
    final rec = _reconciliationData;
    final rDiff = ((rec?['commodities']?['Rice']?['difference_kg'] as num?)?.toDouble()) ?? 0.0;
    final wDiff = ((rec?['commodities']?['Wheat']?['difference_kg'] as num?)?.toDouble()) ?? 0.0;
    final hasVariance = rDiff != 0.0 || wDiff != 0.0;
    final hasExceptionReason = _exceptionReasonController.text.trim().isNotEmpty;
    final canClose = _shopOperationalStatus == 'OPEN' && (!hasVariance || hasExceptionReason);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: _govNavy, size: 22),
              const SizedBox(width: 8),
              const Text('Stage 08: End-of-Day Closure & Ledger Sealing', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _govNavy)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDayClosed ? _govGreenBg : _amberBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isDayClosed ? 'DAY CLOSED SUCCESSFULLY' : 'CLOSURE PENDING',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDayClosed ? _govGreen : _amberAlert),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Finalize all operational records, reconcile inventory, and lock shop transactions for today.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          // Operational Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              children: [
                _buildSummaryLine('Total Beneficiary Transactions Today', '${_digitalRegister.length} distributions'),
                const Divider(height: 12),
                _buildSummaryLine('Remaining Rice Stock', '${_riceStockKg.toStringAsFixed(1)} kg'),
                const Divider(height: 12),
                _buildSummaryLine('Remaining Wheat Stock', '${_wheatStockKg.toStringAsFixed(1)} kg'),
                const Divider(height: 12),
                _buildSummaryLine('Stock Reconciliation Status', (!hasVariance || hasExceptionReason) ? 'RECONCILED / DOCUMENTED' : 'VARIANCE UNRESOLVED'),
                if (isDayClosed) ...[
                  const Divider(height: 12),
                  _buildSummaryLine('Official Closure ID', _closureId ?? "CLS-COMPLETED", isHighlight: true),
                  const Divider(height: 12),
                  _buildSummaryLine('Closed At', _closedAt ?? "Recent", isHighlight: true),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Close Day Action
          if (!isDayClosed)
            Center(
              child: Column(
                children: [
                  if (!canClose)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Document reconciliation exception reason in Stage 07 before closing day.',
                          style: TextStyle(fontSize: 11, color: _dangerRed, fontWeight: FontWeight.bold)),
                    ),
                  ElevatedButton.icon(
                    onPressed: canClose ? _handleCloseShop : null,
                    icon: _isActionLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.lock_rounded, size: 18),
                    label: const Text('CLOSE TODAY\'S OPERATIONS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dangerRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _govGreenBorder)),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: _govGreen, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TODAY\'S OPERATIONS SUCCESSFULLY CLOSED', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _govGreen)),
                        Text('All registers and receipts are permanently sealed and synced with the District Civil Supplies ledger.',
                            style: TextStyle(fontSize: 11, color: _slate700)),
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

  Widget _buildSummaryLine(String title, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 11.5, color: isHighlight ? _govNavy : _slate700, fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isHighlight ? _govGreen : _slate900)),
      ],
    );
  }

  // ================================================================
  // 10. RIGHT CONTEXTUAL OPERATIONAL PANEL
  // ================================================================
  Widget _buildRightContextualPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Current Warehouse Stock Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_rounded, size: 16, color: _govNavy),
                  SizedBox(width: 6),
                  Text('Warehouse Stock Live', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _govNavy)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(6), border: Border.all(color: _slate200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rice (NFSA)', style: TextStyle(fontSize: 10, color: _slate500)),
                          Text('${_riceStockKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _govNavy)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(6), border: Border.all(color: _slate200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wheat (NFSA)', style: TextStyle(fontSize: 10, color: _slate500)),
                          Text('${_wheatStockKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _govNavy)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Quick Operations Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics_rounded, size: 16, color: _govNavy),
                  SizedBox(width: 6),
                  Text('Today\'s Overview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _govNavy)),
                ],
              ),
              const SizedBox(height: 8),
              _buildRightStatRow('Beneficiaries Served Today', '${_digitalRegister.length}'),
              const Divider(height: 12),
              _buildRightStatRow('Pending Consignments', '${_consignments.where((c) => c['status'] != 'RECEIVED').length}'),
              const Divider(height: 12),
              _buildRightStatRow('e-PoS Connectivity', 'ONLINE (GSM 4G)'),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Quick Actions
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Operations Quick Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _govNavy)),
              const SizedBox(height: 8),
              _buildQuickActionButton('VIEW STOCK MOVEMENTS', Icons.menu_book_rounded, _showStockLedgerDialog),
              const SizedBox(height: 6),
              _buildQuickActionButton('VIEW DIGITAL REGISTER', Icons.receipt_long_rounded, () => setState(() => _activeStep = 5)),
              const SizedBox(height: 6),
              _buildQuickActionButton('CHECK RECONCILIATION', Icons.balance_rounded, () => setState(() => _activeStep = 6)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: _slate500)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate900)),
      ],
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _govNavy,
        minimumSize: const Size(double.infinity, 34),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }

  // ================================================================
  // 11. SIDEBAR VIEWS: REPORTS, SETTINGS
  // ================================================================
  Widget _buildReportsView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operational Reports & Compliance Audit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _govNavy)),
          const Text('Daily distribution volumes and stock reconciliation summaries.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildMetricCard('Total Distributions', '${_digitalRegister.length}', Icons.point_of_sale_rounded, _govNavy),
              const SizedBox(width: 14),
              _buildMetricCard('Warehouse Rice Stock', '${_riceStockKg.toStringAsFixed(0)} kg', Icons.inventory_2_rounded, _govGreen),
              const SizedBox(width: 14),
              _buildMetricCard('Warehouse Wheat Stock', '${_wheatStockKg.toStringAsFixed(0)} kg', Icons.warehouse_rounded, _amberAlert),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FPS Terminal Settings & Device Linkage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _govNavy)),
          const Text('Configuration parameters for Fair Price Shop hardware & gateway.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.point_of_sale_rounded, color: _govNavy),
                  title: Text('Visiontek 92 e-PoS Gateway', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('Device ID: EPOS-KA-BAG-001 • Biometric Optical Scanner Active', style: TextStyle(fontSize: 11, color: _slate500)),
                  trailing: Icon(Icons.check_circle_rounded, color: _govGreen),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.scale_rounded, color: _govNavy),
                  title: Text('Electronic Weighing Scale Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('RS232 Serial Port Connected • Zero Drift Calibrated', style: TextStyle(fontSize: 11, color: _slate500)),
                  trailing: Icon(Icons.check_circle_rounded, color: _govGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
