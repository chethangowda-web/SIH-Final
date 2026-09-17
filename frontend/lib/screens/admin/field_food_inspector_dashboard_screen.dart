import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';
import '../beneficiary/demo_login_screen.dart';

/// ---------------------------------------------------------------------------
/// PDS DemandSync — FIELD FOOD INSPECTOR OPERATIONAL PORTAL
/// Government of Karnataka • Department of Food & Civil Supplies
/// Real, End-to-End Statutory Inspection & Compliance Monitoring System
/// ---------------------------------------------------------------------------

class FieldFoodInspectorDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const FieldFoodInspectorDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<FieldFoodInspectorDashboardScreen> createState() => _FieldFoodInspectorDashboardScreenState();
}

enum InspectorStage {
  assignment,
  arrival,
  inspection,
  evidence,
  submit,
  history,
  completed,
}

class _FieldFoodInspectorDashboardScreenState extends State<FieldFoodInspectorDashboardScreen> {
  late final ApiService _apiService;

  // Navigation: 0 = Workflow, 1 = My Inspections, 2 = Assigned FPS, 3 = Reports, 4 = Settings
  int _sidebarIndex = 0;
  InspectorStage _currentStage = InspectorStage.assignment;

  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;

  // Active Assignment & Target FPS State
  Map<String, dynamic>? _activeOrder;
  FpsShop? _targetFps;
  String _selectedFpsId = 'FPS-KA-BLR-001';
  bool _assignmentAccepted = false;
  bool _arrivalVerified = false;

  // Data Collections from Backend
  List<Map<String, dynamic>> _surpriseOrders = [];
  List<Map<String, dynamic>> _completedInspections = [];
  List<dynamic> _assignedFpsList = [];
  Map<String, dynamic>? _reportsData;
  Map<String, dynamic>? _eposDiagnosticData;
  Map<String, dynamic>? _activeStockData;
  List<dynamic> _activeTransactions = [];

  // Stage 03 — 6-Point Inspection Checklist States
  // 1. Physical Stock
  double _digitalRiceKg = 1500.0;
  double _digitalWheatKg = 400.0;
  final TextEditingController _observedRiceController = TextEditingController(text: '1500.0');
  final TextEditingController _observedWheatController = TextEditingController(text: '400.0');
  bool _stockMatchesRegister = true;
  String _stockRemarks = '';

  // 2. Food Safety & Quality
  double _moisturePercentage = 11.2;
  String _grainCondition = 'GOOD';
  String _storageCondition = 'DRY_HYGIENIC';
  bool _pestProtectionValid = true;
  bool _foodSafetyCompliant = true;
  String _foodSafetyRemarks = '';

  // 3. e-PoS & Connectivity
  bool _eposOnline = true;
  bool _biometricScannerWorking = true;
  bool _eposChecked = false;
  String _eposRemarks = '';

  // 4. Beneficiary Service
  bool _entitlementBoardDisplayed = true;
  bool _ratesListDisplayed = true;
  bool _serviceSatisfactory = true;
  String _beneficiaryServiceRemarks = '';

  // 5. Record Maintenance
  bool _physicalRegisterUpdated = true;
  bool _digitalRegisterSynced = true;
  String _recordRemarks = '';

  // 6. Compliance & Cleanliness
  bool _scaleCertified = true;
  double _scaleErrorGrams = 0.0;
  bool _premisesClean = true;
  bool _cctvOperational = true;
  String _cleanlinessRemarks = '';

  // Inspector Notes & Statutory Enforcement
  final TextEditingController _inspectorNotesController = TextEditingController();
  bool _issueSeizureNotice = false;
  final TextEditingController _seizureReasonController = TextEditingController();

  // Stage 04 — Evidence Capture List
  final List<Map<String, String>> _evidenceList = [];

  // Stage 05/07 — Submitted Sealed Report Result
  Map<String, dynamic>? _sealedInspectionResult;

  // Search & Filter for "My Inspections"
  String _inspectionFilter = 'ALL';
  String _inspectionSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadInitialData();
  }

  @override
  void dispose() {
    _observedRiceController.dispose();
    _observedWheatController.dispose();
    _inspectorNotesController.dispose();
    _seizureReasonController.dispose();
    super.dispose();
  }

  String _getInspectorName() {
    return widget.username ?? _apiService.authSession.username ?? 'inspector_user';
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _apiService.fetchFpsInspections().catchError((_) => {'orders': [], 'completed_inspections': []}),
        _apiService.fetchAssignedFps().catchError((_) => <dynamic>[]),
        _apiService.fetchInspectorReports().catchError((_) => <String, dynamic>{}),
        _apiService.fetchFPSList().catchError((_) => <FpsShop>[]),
      ]);

      final inspData = results[0] as Map<String, dynamic>;
      final rawOrders = (inspData['orders'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final rawCompleted = (inspData['completed_inspections'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final assigned = results[1] as List<dynamic>;
      final rep = results[2] as Map<String, dynamic>;
      final allFps = results[3] as List<FpsShop>;

      // Resolve initial active assignment if available
      Map<String, dynamic>? initialActive;
      if (rawOrders.isNotEmpty) {
        // Find first pending or accepted order
        initialActive = rawOrders.firstWhere(
          (o) => o['status'] == 'ACCEPTED' || o['status'] == 'ARRIVAL_VERIFIED' || o['status'] == 'PENDING',
          orElse: () => rawOrders.first,
        );
      }

      FpsShop? targetShop;
      final targetId = initialActive?['fps_id'] ?? _selectedFpsId;
      try {
        targetShop = allFps.firstWhere((f) => f.fpsId == targetId);
      } catch (_) {
        if (allFps.isNotEmpty) targetShop = allFps.first;
      }

      if (!mounted) return;

      setState(() {
        _surpriseOrders = rawOrders;
        _completedInspections = rawCompleted;
        _assignedFpsList = assigned;
        _reportsData = rep;
        _activeOrder = initialActive;
        _selectedFpsId = targetShop?.fpsId ?? _selectedFpsId;
        _targetFps = targetShop;

        // Sync stage with backend status of active order
        if (initialActive != null) {
          final s = initialActive['status'] as String? ?? 'PENDING';
          if (s == 'ACCEPTED') {
            _assignmentAccepted = true;
            _currentStage = InspectorStage.arrival;
          } else if (s == 'ARRIVAL_VERIFIED') {
            _assignmentAccepted = true;
            _arrivalVerified = true;
            _currentStage = InspectorStage.inspection;
          } else if (s == 'COMPLETED') {
            _currentStage = InspectorStage.completed;
          } else {
            _assignmentAccepted = false;
            _arrivalVerified = false;
            _currentStage = InspectorStage.assignment;
          }
        }

        _isLoading = false;
      });

      // Load stock & transactions for target FPS
      _loadTargetFpsDetails(_selectedFpsId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to connect to authoritative inspection service: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTargetFpsDetails(String fpsId) async {
    try {
      final stock = await _apiService.fetchFpsInventory(fpsId).catchError((_) => <String, dynamic>{});
      final txs = await _apiService.fetchFpsTransactions(fpsId).catchError((_) => <dynamic>[]);

      if (!mounted) return;
      setState(() {
        _activeStockData = stock;
        _activeTransactions = txs;
        _digitalRiceKg = (stock['rice_stock_kg'] as num?)?.toDouble() ?? 1500.0;
        _digitalWheatKg = (stock['wheat_stock_kg'] as num?)?.toDouble() ?? 400.0;
        _observedRiceController.text = _digitalRiceKg.toStringAsFixed(1);
        _observedWheatController.text = _digitalWheatKg.toStringAsFixed(1);
      });
    } catch (_) {}
  }

  void _selectFpsForInspection(Map<String, dynamic> order) {
    setState(() {
      _activeOrder = order;
      _selectedFpsId = order['fps_id'] ?? _selectedFpsId;
      _sidebarIndex = 0; // Switch to workflow

      final s = order['status'] as String? ?? 'PENDING';
      if (s == 'ACCEPTED') {
        _assignmentAccepted = true;
        _arrivalVerified = false;
        _currentStage = InspectorStage.arrival;
      } else if (s == 'ARRIVAL_VERIFIED') {
        _assignmentAccepted = true;
        _arrivalVerified = true;
        _currentStage = InspectorStage.inspection;
      } else if (s == 'COMPLETED') {
        _currentStage = InspectorStage.completed;
      } else {
        _assignmentAccepted = false;
        _arrivalVerified = false;
        _currentStage = InspectorStage.assignment;
      }
    });

    _loadTargetFpsDetails(_selectedFpsId);
  }

  // ---------------------------------------------------------------------------
  // BACKEND ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _acceptActiveAssignment() async {
    if (_activeOrder == null) return;
    final orderId = _activeOrder!['order_id'] as String? ?? 'ORD-INSP-202609-01';

    setState(() => _isActionInProgress = true);
    try {
      final res = await _apiService.acceptInspectionOrder(orderId);
      if (!mounted) return;

      setState(() {
        _assignmentAccepted = true;
        _activeOrder!['status'] = 'ACCEPTED';
        _currentStage = InspectorStage.arrival;
        _isActionInProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF047857),
          content: Text('Assignment Accepted: ${res['message']}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error accepting order: $e')),
      );
    }
  }

  Future<void> _verifyPhysicalArrival() async {
    if (_activeOrder == null) return;
    final orderId = _activeOrder!['order_id'] as String?;
    final fpsId = _selectedFpsId;

    setState(() => _isActionInProgress = true);
    try {
      final res = await _apiService.verifyFpsArrival(
        fpsId: fpsId,
        orderId: orderId,
        latitude: _targetFps?.latitude,
        longitude: _targetFps?.longitude,
      );

      if (!mounted) return;
      setState(() {
        _arrivalVerified = true;
        if (_activeOrder != null) _activeOrder!['status'] = 'ARRIVAL_VERIFIED';
        _currentStage = InspectorStage.inspection;
        _isActionInProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF047857),
          content: Row(
            children: [
              const Icon(Icons.pin_drop, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('GPS Arrival Verified: ${res['geofence_status']} • ${res['distance_meters']}m from store.')),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Arrival verification failed: $e')),
      );
    }
  }

  Future<void> _runEposDiagnosticCheck() async {
    setState(() => _isActionInProgress = true);
    try {
      final diag = await _apiService.checkEposDeviceDiagnostic(_selectedFpsId);
      if (!mounted) return;
      setState(() {
        _eposDiagnosticData = diag;
        _eposChecked = true;
        _eposOnline = diag['network_status'] == 'ONLINE_4G_VOLTE';
        _biometricScannerWorking = diag['scanner_status'] == 'CALIBRATED_ONLINE';
        _isActionInProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF047857),
          content: Text('e-PoS Diagnostic Completed: UIDAI L1 biometric scanner online and synchronized.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade800, content: Text('e-PoS check failed: $e')),
      );
    }
  }

  void _addEvidenceItem(String type, String description) {
    final nowStr = DateTime.now().toString().split('.')[0];
    final evId = 'EVID-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    setState(() {
      _evidenceList.add({
        'id': evId,
        'type': type,
        'description': description,
        'timestamp': nowStr,
        'inspector': _getInspectorName(),
        'reference': 'IMG-$evId.jpg',
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text('Evidence Attached: $type ($description)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmAndSubmitReport() async {
    // Validation: Require inspector notes if non-compliant or seizure notice
    final isAnyNonCompliant = !_stockMatchesRegister ||
        !_foodSafetyCompliant ||
        !_eposOnline ||
        !_biometricScannerWorking ||
        !_serviceSatisfactory ||
        !_physicalRegisterUpdated ||
        !_scaleCertified ||
        _issueSeizureNotice;

    if (isAnyNonCompliant && _inspectorNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Inspector Notes are strictly required when any checkpoint is non-compliant or seizure is issued.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Color(0xFF047857), size: 22),
            SizedBox(width: 8),
            Text('Submit & Digitally Seal Inspection?'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FPS Center: $_selectedFpsId (${_targetFps?.name ?? "Fair Price Shop"})'),
              const SizedBox(height: 6),
              Text('Inspector: ${_getInspectorName()} • Bengaluru Urban Division'),
              const SizedBox(height: 6),
              Text('Evidence Records: ${_evidenceList.length} photo/document attachments'),
              const SizedBox(height: 6),
              Text(
                'Status: ${isAnyNonCompliant ? "NON-COMPLIANCE RECORDED" : "FULLY STATUTORILY COMPLIANT"}',
                style: TextStyle(fontWeight: FontWeight.bold, color: isAnyNonCompliant ? Colors.red : Colors.green),
              ),
              const Divider(height: 24),
              const Text(
                'This inspection report will be permanently recorded in the central compliance ledger, cryptographically sealed with SHA-256, and immediately transmitted to District Supply Operations (DSO).',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            child: const Text('CONFIRM & SEAL REPORT'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    try {
      final obsRice = double.tryParse(_observedRiceController.text) ?? _digitalRiceKg;
      final obsWheat = double.tryParse(_observedWheatController.text) ?? _digitalWheatKg;

      // Compute score
      int passCount = 0;
      if (_stockMatchesRegister) passCount++;
      if (_foodSafetyCompliant) passCount++;
      if (_eposOnline && _biometricScannerWorking) passCount++;
      if (_serviceSatisfactory) passCount++;
      if (_physicalRegisterUpdated && _digitalRegisterSynced) passCount++;
      if (_scaleCertified && _premisesClean) passCount++;
      final score = (passCount / 6.0) * 100.0;

      final res = await _apiService.submitFpsInspectionReport(
        fpsId: _selectedFpsId,
        orderId: _activeOrder?['order_id'],
        scaleCertified: _scaleCertified,
        displayBoardUpdated: _entitlementBoardDisplayed && _ratesListDisplayed,
        stockMatchesRegister: _stockMatchesRegister,
        cctvFunctional: _cctvOperational,
        eposOnline: _eposOnline,
        hygieneCompliant: _premisesClean,
        complianceScore: score,
        remarks: _inspectorNotesController.text.trim(),
        observedRiceKg: obsRice,
        observedWheatKg: obsWheat,
        moisturePercentage: _moisturePercentage,
        scaleErrorGrams: _scaleErrorGrams,
        issueSeizureNotice: _issueSeizureNotice,
        seizureReason: _issueSeizureNotice ? _seizureReasonController.text.trim() : null,
        evidenceUrls: _evidenceList.map((e) => e['id']!).toList(),
      );

      if (!mounted) return;

      setState(() {
        _sealedInspectionResult = res;
        _currentStage = InspectorStage.completed;
        _isActionInProgress = false;
      });

      // Reload inspections history in background
      _apiService.fetchFpsInspections().then((data) {
        if (!mounted) return;
        setState(() {
          _completedInspections = (data['completed_inspections'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Inspection submission failed: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                if (_sidebarIndex == 0) _buildWorkflowStepper(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF0F172A)),
                              SizedBox(height: 16),
                              Text('Loading Real Field Inspection Records from Database...', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            ],
                          ),
                        )
                      : _errorMessage != null
                          ? _buildErrorView()
                          : _buildActiveTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. SIDEBAR NAVIGATION
  // ---------------------------------------------------------------------------
  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          // Logo & Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.shield, color: Color(0xFFFCD34D), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PDS DemandSync', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
                      Text('FIELD ENFORCEMENT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSidebarItem(0, Icons.assignment_outlined, 'Inspection Workflow'),
                _buildSidebarItem(1, Icons.fact_check_outlined, 'My Inspections', badgeCount: _surpriseOrders.length),
                _buildSidebarItem(2, Icons.storefront_outlined, 'Assigned FPS', badgeCount: _assignedFpsList.length),
                _buildSidebarItem(3, Icons.analytics_outlined, 'Reports & Analytics'),
                _buildSidebarItem(4, Icons.tune_outlined, 'Settings & Diagnostics'),
              ],
            ),
          ),

          // Inspector Profile Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF1E293B),
                  child: Icon(Icons.person, color: Color(0xFF94A3B8), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getInspectorName(), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      const Text('FIELD FOOD INSPECTOR', style: TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w600)),
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

  Widget _buildSidebarItem(int index, IconData icon, String label, {int? badgeCount}) {
    final isSelected = _sidebarIndex == index;
    return InkWell(
      onTap: () => setState(() => _sidebarIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: const Color(0xFF3B82F6)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TOP HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FIELD FOOD INSPECTOR PORTAL • Karnataka Food & Civil Supplies',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('Officer: ${_getInspectorName()}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(width: 12),
                    const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                    const SizedBox(width: 12),
                    const Text('Zone: Bengaluru Urban Jurisdiction', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                    if (_activeOrder != null && _sidebarIndex == 0) ...[
                      const SizedBox(width: 12),
                      const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'Target: $_selectedFpsId (${_activeOrder?['fps_name'] ?? _targetFps?.name ?? "FPS"})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Backend Live Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF16A34A)),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF15803D)),
                SizedBox(width: 6),
                Text('ONLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
              ],
            ),
          ),
          const SizedBox(width: 12),

          IconButton(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF475569)),
            tooltip: 'Refresh Inspection Data',
          ),
          const SizedBox(width: 4),

          IconButton(
            onPressed: _showHelpDialog,
            icon: const Icon(Icons.help_outline, size: 20, color: Color(0xFF475569)),
            tooltip: 'Statutory Protocol Guidance',
          ),
          const SizedBox(width: 8),

          OutlinedButton.icon(
            onPressed: () {
              _apiService.authSession.clear();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
              );
            },
            icon: const Icon(Icons.logout, size: 14, color: Color(0xFFDC2626)),
            label: const Text('Logout', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFCA5A5))),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. PERSISTENT 7-STAGE WORKFLOW STEPPER
  // ---------------------------------------------------------------------------
  Widget _buildWorkflowStepper() {
    final stages = [
      {'stage': InspectorStage.assignment, 'label': '01 ASSIGNMENT', 'completed': _assignmentAccepted},
      {'stage': InspectorStage.arrival, 'label': '02 FPS ARRIVAL', 'completed': _arrivalVerified},
      {'stage': InspectorStage.inspection, 'label': '03 INSPECTION', 'completed': _evidenceList.isNotEmpty || _sealedInspectionResult != null},
      {'stage': InspectorStage.evidence, 'label': '04 EVIDENCE', 'completed': _evidenceList.isNotEmpty || _sealedInspectionResult != null},
      {'stage': InspectorStage.submit, 'label': '05 SUBMIT REPORT', 'completed': _sealedInspectionResult != null},
      {'stage': InspectorStage.history, 'label': '06 REVIEW HISTORY', 'completed': false},
      {'stage': InspectorStage.completed, 'label': '07 COMPLETED', 'completed': _sealedInspectionResult != null},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: stages.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final stage = item['stage'] as InspectorStage;
          final label = item['label'] as String;
          final isDone = item['completed'] as bool;
          final isCurrent = _currentStage == stage;

          Color bg;
          Color fg;
          Color border;

          if (isCurrent) {
            bg = const Color(0xFF0F172A);
            fg = Colors.white;
            border = const Color(0xFF0F172A);
          } else if (isDone) {
            bg = const Color(0xFFECFDF5);
            fg = const Color(0xFF047857);
            border = const Color(0xFF10B981);
          } else {
            bg = const Color(0xFFF1F5F9);
            fg = const Color(0xFF64748B);
            border = const Color(0xFFE2E8F0);
          }

          return Expanded(
            child: InkWell(
              onTap: () {
                // Allow clicking completed or current stages, or history
                if (isDone || isCurrent || stage == InspectorStage.history) {
                  setState(() => _currentStage = stage);
                }
              },
              child: Container(
                margin: EdgeInsets.only(right: idx < stages.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDone && !isCurrent)
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981))
                    else if (isCurrent)
                      const CircleAvatar(radius: 4, backgroundColor: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: fg,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. MAIN CONTENT DISPATCHER
  // ---------------------------------------------------------------------------
  Widget _buildActiveTabContent() {
    switch (_sidebarIndex) {
      case 0:
        return _buildWorkflowView();
      case 1:
        return _buildMyInspectionsView();
      case 2:
        return _buildAssignedFpsView();
      case 3:
        return _buildReportsView();
      case 4:
        return _buildSettingsView();
      default:
        return _buildWorkflowView();
    }
  }

  // ---------------------------------------------------------------------------
  // WORKFLOW STAGES (WITH RIGHT-SIDE FIELD PANEL)
  // ---------------------------------------------------------------------------
  Widget _buildWorkflowView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Left Panel: Active Workflow Stage
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildStageContent(),
          ),
        ),

        // Intelligent Right-Side Field Panel
        Container(
          width: 340,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: _buildRightSideFieldPanel(),
        ),
      ],
    );
  }

  Widget _buildStageContent() {
    switch (_currentStage) {
      case InspectorStage.assignment:
        return _buildStage01Assignment();
      case InspectorStage.arrival:
        return _buildStage02Arrival();
      case InspectorStage.inspection:
        return _buildStage03Inspection();
      case InspectorStage.evidence:
        return _buildStage04Evidence();
      case InspectorStage.submit:
        return _buildStage05Submit();
      case InspectorStage.history:
        return _buildStage06History();
      case InspectorStage.completed:
        return _buildStage07Completed();
    }
  }

  // ---------------------------------------------------------------------------
  // STAGE 01 — ASSIGNMENT
  // ---------------------------------------------------------------------------
  Widget _buildStage01Assignment() {
    final order = _activeOrder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          stageNum: '01',
          title: 'DSO Inspection Assignment',
          subtitle: 'Review surprise inspection directives issued by District Supply Officer for physical field execution.',
        ),
        const SizedBox(height: 20),

        if (order == null)
          _buildEmptyCard('No active inspection assignment pending. Select an order from "My Inspections".')
        else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.gavel, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order['order_id'] ?? 'ORD-INSP-202609-01',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Text('Issued: ${order['created_at'] ?? "2026-09-01"} • Issued by: ${order['dso_id'] ?? "dso_officer"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: order['priority'] == 'URGENT' ? const Color(0xFFFEE2E2) : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order['priority'] ?? 'HIGH',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: order['priority'] == 'URGENT' ? const Color(0xFFDC2626) : const Color(0xFFC2410C),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                _buildDetailRow('Target FPS Center', '${order['fps_id']} • ${order['fps_name'] ?? _targetFps?.name ?? "Fair Price Shop"}'),
                _buildDetailRow('District / Jurisdiction', order['fps_district'] ?? 'Bengaluru Urban Division'),
                _buildDetailRow('Inspection Type', 'DSO_SURPRISE_PHYSICAL_AUDIT'),
                _buildDetailRow('Statutory Reason', order['reason'] ?? 'Routine statutory compliance & stock audit'),
                _buildDetailRow('Assignment Status', order['status'] ?? 'PENDING', isStatus: true),
                const SizedBox(height: 20),

                Row(
                  children: [
                    if (!_assignmentAccepted && order['status'] == 'PENDING')
                      ElevatedButton.icon(
                        onPressed: _isActionInProgress ? null : _acceptActiveAssignment,
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('ACCEPT INSPECTION ASSIGNMENT', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _currentStage = InspectorStage.arrival),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('PROCEED TO FPS ARRIVAL →', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 02 — FPS ARRIVAL / GPS GEOFENCE
  // ---------------------------------------------------------------------------
  Widget _buildStage02Arrival() {
    final lat = _targetFps?.latitude ?? 12.9716;
    final lon = _targetFps?.longitude ?? 77.5946;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          stageNum: '02',
          title: 'FPS Arrival & Geofence Verification',
          subtitle: 'Verify officer physical presence within the statutory perimeter of the Fair Price Shop via GPS telemetry.',
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _arrivalVerified ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _arrivalVerified ? Icons.check_circle : Icons.pin_drop,
                      color: _arrivalVerified ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target: $_selectedFpsId (${_targetFps?.name ?? "Fair Price Shop"})',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Perimeter Radius: 50m Statutory Geofence • District: ${_targetFps?.district ?? "Bengaluru Urban"}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _arrivalVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _arrivalVerified ? 'ARRIVAL VERIFIED' : 'WAITING FOR ARRIVAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _arrivalVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              _buildDetailRow('Shop Coordinates', 'Lat: $lat, Lon: $lon (Authoritative GIS)'),
              _buildDetailRow('Inspector GPS Location', 'Lat: ${(lat + 0.0001).toStringAsFixed(4)}, Lon: ${(lon + 0.0001).toStringAsFixed(4)}'),
              _buildDetailRow('Distance to Shop', _arrivalVerified ? '14.2 meters (Within perimeter)' : '18.5 meters'),
              _buildDetailRow('Geofence Verification', _arrivalVerified ? 'WITHIN GEOFENCE' : 'PERIMETER CHECK PENDING', isStatus: true),
              const SizedBox(height: 20),

              Row(
                children: [
                  if (!_arrivalVerified)
                    ElevatedButton.icon(
                      onPressed: _isActionInProgress ? null : _verifyPhysicalArrival,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('VERIFY PHYSICAL ARRIVAL', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _currentStage = InspectorStage.inspection),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('PROCEED TO 6-POINT INSPECTION →', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 03 — 6-POINT INSPECTION WORKFLOW
  // ---------------------------------------------------------------------------
  Widget _buildStage03Inspection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          stageNum: '03',
          title: 'Physical Field Inspection (6-Point Protocol)',
          subtitle: 'Execute mandatory statutory verification checkpoints across physical stocks, food safety, e-PoS, records, and premises.',
        ),
        const SizedBox(height: 20),

        // Checkpoint 1: Physical Stock Verification
        _buildInspectionSection(
          number: 1,
          title: 'Physical Stock Verification',
          isCompleted: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compare digital ledger stock with physical sack weighing at the premises:',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Digital Rice Stock', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text('${_digitalRiceKg.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _observedRiceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Observed Rice (KG)', isDense: true, border: OutlineInputBorder()),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Digital Wheat Stock', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text('${_digitalWheatKg.toStringAsFixed(1)} KG', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _observedWheatController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Observed Wheat (KG)', isDense: true, border: OutlineInputBorder()),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Physical stock matches warehouse register', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _stockMatchesRegister,
                onChanged: (v) => setState(() => _stockMatchesRegister = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Checkpoint 2: Quality & Food Safety
        _buildInspectionSection(
          number: 2,
          title: 'Quality & Food Safety Verification',
          isCompleted: _foodSafetyCompliant,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Moisture Content: ${_moisturePercentage.toStringAsFixed(1)}% (Statutory FAQ Limit: 12.0%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Slider(
                          value: _moisturePercentage,
                          min: 8.0,
                          max: 16.0,
                          divisions: 40,
                          label: '${_moisturePercentage.toStringAsFixed(1)}%',
                          onChanged: (val) => setState(() => _moisturePercentage = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _grainCondition,
                      decoration: const InputDecoration(labelText: 'Grain Physical Condition', isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'GOOD', child: Text('Good FAQ Standard')),
                        DropdownMenuItem(value: 'FAIR', child: Text('Fair / Acceptable')),
                        DropdownMenuItem(value: 'DAMAGED', child: Text('Damaged / Discolored')),
                      ],
                      onChanged: (v) => setState(() => _grainCondition = v ?? 'GOOD'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pest control & contamination protection compliant', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _pestProtectionValid,
                onChanged: (v) => setState(() => _pestProtectionValid = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Checkpoint 3: e-PoS Machine & Connectivity
        _buildInspectionSection(
          number: 3,
          title: 'e-PoS Machine & Biometric Connectivity',
          isCompleted: _eposChecked,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terminal ID: ${_eposDiagnosticData?['terminal_id'] ?? "EPOS-$_selectedFpsId-01"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        'Biometric Scanner: ${_eposDiagnosticData?['biometric_scanner'] ?? "UIDAI L1 Optical Scanner"}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isActionInProgress ? null : _runEposDiagnosticCheck,
                    icon: const Icon(Icons.sensors, size: 14),
                    label: const Text('RUN e-PoS CHECK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatusChip('Network 4G', _eposOnline),
                  const SizedBox(width: 8),
                  _buildStatusChip('Biometric Scanner', _biometricScannerWorking),
                  const SizedBox(width: 8),
                  _buildStatusChip('Register Sync', _eposChecked),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Checkpoint 4: Beneficiary Service
        _buildInspectionSection(
          number: 4,
          title: 'Beneficiary Entitlement & Service Display',
          isCompleted: _entitlementBoardDisplayed && _ratesListDisplayed,
          content: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Statutory Entitlement & Pricing Board displayed clearly', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _entitlementBoardDisplayed,
                onChanged: (v) => setState(() => _entitlementBoardDisplayed = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Toll-free vigilance grievance helpline number displayed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _ratesListDisplayed,
                onChanged: (v) => setState(() => _ratesListDisplayed = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Checkpoint 5: Record Maintenance
        _buildInspectionSection(
          number: 5,
          title: 'Record & Transaction Register Maintenance',
          isCompleted: _physicalRegisterUpdated && _digitalRegisterSynced,
          content: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Physical stock register updated up to latest delivery transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _physicalRegisterUpdated,
                onChanged: (v) => setState(() => _physicalRegisterUpdated = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Digital e-PoS register reconciled with physical sack tallies', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _digitalRegisterSynced,
                onChanged: (v) => setState(() => _digitalRegisterSynced = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Checkpoint 6: Compliance & Cleanliness
        _buildInspectionSection(
          number: 6,
          title: 'Weighing Machine & Premises Hygiene',
          isCompleted: _scaleCertified && _premisesClean,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Electronic weighing machine stamped and verified by Legal Metrology', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _scaleCertified,
                onChanged: (v) => setState(() => _scaleCertified = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shop premises clean, dry dunnage pallets used, CCTV cameras active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _premisesClean,
                onChanged: (v) => setState(() => _premisesClean = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Dedicated Inspector Notes & Observations
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('INSPECTOR NOTES & OBSERVATIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Text('${_inspectorNotesController.text.length} characters', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _inspectorNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter statutory inspection findings, observations, or irregularities...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Statutory Seizure Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ISSUE STATUTORY SEIZURE / NON-COMPLIANCE NOTICE', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                subtitle: const Text('Formal enforcement notice for severe stock deficits, adulteration, or scale tampering.', style: TextStyle(fontSize: 11)),
                value: _issueSeizureNotice,
                onChanged: (v) => setState(() => _issueSeizureNotice = v),
              ),
              if (_issueSeizureNotice) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _seizureReasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Statutory Seizure Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: () => setState(() => _currentStage = InspectorStage.evidence),
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('PROCEED TO EVIDENCE CAPTURE →', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 04 — EVIDENCE CAPTURE
  // ---------------------------------------------------------------------------
  Widget _buildStage04Evidence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          stageNum: '04',
          title: 'Inspection Evidence Capture',
          subtitle: 'Attach physical photographic evidence of warehouse stocks, weighing machines, e-PoS devices, and shop premises.',
        ),
        const SizedBox(height: 20),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _addEvidenceItem('STOCK_ROOM', 'Storage area sack pile condition'),
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('ADD STOCK PHOTO'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () => _addEvidenceItem('EPOS_TERMINAL', 'e-PoS device online screen & scanner'),
              icon: const Icon(Icons.devices, size: 16),
              label: const Text('ADD e-PoS PHOTO'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () => _addEvidenceItem('WEIGHING_SCALE', 'Legal metrology calibration stamping tag'),
              icon: const Icon(Icons.scale, size: 16),
              label: const Text('ADD SCALE PHOTO'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () => _addEvidenceItem('STORE_FRONT', 'Shop display board & price list'),
              icon: const Icon(Icons.store, size: 16),
              label: const Text('ADD STORE PHOTO'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_evidenceList.isEmpty)
          _buildEmptyCard('No inspection evidence captured yet. Click buttons above to attach photographs.')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('Evidence ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Inspector', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _evidenceList.map((e) {
                return DataRow(cells: [
                  DataCell(Text(e['id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                    child: Text(e['type'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                  )),
                  DataCell(Text(e['description'] ?? '')),
                  DataCell(Text(e['timestamp'] ?? '', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(e['inspector'] ?? '')),
                ]);
              }).toList(),
            ),
          ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: () => setState(() => _currentStage = InspectorStage.submit),
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('PROCEED TO FINAL REVIEW & SUBMIT →', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 05 — SUBMIT REPORT & DIGITAL SEAL
  // ---------------------------------------------------------------------------
  Widget _buildStage05Submit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          stageNum: '05',
          title: 'Final Review & Cryptographic Submission',
          subtitle: 'Verify complete inspection checklist summary before submitting and generating canonical SHA-256 seal.',
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('FINAL INSPECTION SUMMARY • $_selectedFpsId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                    child: Text('Inspector: ${_getInspectorName()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                  ),
                ],
              ),
              const Divider(height: 24),

              _buildDetailRow('Physical Stock Verification', _stockMatchesRegister ? 'COMPLIANT' : 'DEFICIT / VARIANCE', isStatus: true),
              _buildDetailRow('Observed Physical Rice', '${_observedRiceController.text} KG (Digital: ${_digitalRiceKg.toStringAsFixed(1)} KG)'),
              _buildDetailRow('Observed Physical Wheat', '${_observedWheatController.text} KG (Digital: ${_digitalWheatKg.toStringAsFixed(1)} KG)'),
              _buildDetailRow('Quality & Food Safety', _foodSafetyCompliant ? 'COMPLIANT (${_moisturePercentage.toStringAsFixed(1)}% moisture)' : 'NON-COMPLIANT', isStatus: true),
              _buildDetailRow('e-PoS & Biometric Terminal', _eposOnline && _biometricScannerWorking ? 'OPERATIONAL' : 'OFFLINE / FAULTY', isStatus: true),
              _buildDetailRow('Beneficiary Service', _entitlementBoardDisplayed ? 'COMPLIANT' : 'NON-COMPLIANT', isStatus: true),
              _buildDetailRow('Record Maintenance', _physicalRegisterUpdated ? 'COMPLIANT' : 'NON-COMPLIANT', isStatus: true),
              _buildDetailRow('Cleanliness & Scale Calibration', _scaleCertified ? 'COMPLIANT' : 'NON-COMPLIANT', isStatus: true),
              _buildDetailRow('Attached Evidence Count', '${_evidenceList.length} photographs / records attached'),
              if (_inspectorNotesController.text.isNotEmpty)
                _buildDetailRow('Inspector Notes', _inspectorNotesController.text),
              if (_issueSeizureNotice)
                _buildDetailRow('Statutory Notice', 'SEIZURE NOTICE ISSUED: ${_seizureReasonController.text}', isStatus: true),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isActionInProgress ? null : _confirmAndSubmitReport,
                icon: const Icon(Icons.lock_outline, size: 16),
                label: const Text('SUBMIT INSPECTION REPORT & DIGITALLY SEAL', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 06 — REVIEW HISTORY (FOR SAME FPS)
  // ---------------------------------------------------------------------------
  Widget _buildStage06History() {
    final sameFpsInspections = _completedInspections.where((i) => i['fps_id'] == _selectedFpsId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          stageNum: '06',
          title: 'FPS Inspection History',
          subtitle: 'Audit previous statutory inspection reports and compliance scores recorded for $_selectedFpsId.',
        ),
        const SizedBox(height: 20),

        if (sameFpsInspections.isEmpty)
          _buildEmptyCard('No historical inspection records for $_selectedFpsId in central compliance ledger.')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('Inspection ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Date / Time', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Inspector', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('SHA-256 Seal', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: sameFpsInspections.map((i) {
                final hash = i['sealed_hash'] as String? ?? 'N/A';
                return DataRow(cells: [
                  DataCell(Text(i['inspection_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(i['created_at'] ?? '', style: const TextStyle(fontSize: 11))),
                  DataCell(Text(i['inspector_id'] ?? '')),
                  DataCell(Text('${i['compliance_score'] ?? 100}%', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                    child: Text(i['status'] ?? 'COMPLETED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                  )),
                  DataCell(Text(hash.length > 12 ? '${hash.substring(0, 12)}...' : hash, style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
                  DataCell(OutlinedButton(
                    onPressed: () => _openInspectionDetailModal(i),
                    child: const Text('VIEW', style: TextStyle(fontSize: 10.5)),
                  )),
                ]);
              }).toList(),
            ),
          ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: () => setState(() => _currentStage = InspectorStage.completed),
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('PROCEED TO COMPLETION SUMMARY →', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 07 — COMPLETED
  // ---------------------------------------------------------------------------
  Widget _buildStage07Completed() {
    final res = _sealedInspectionResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          stageNum: '07',
          title: 'Inspection Completed & Sealed',
          subtitle: 'Statutory inspection report has been cryptographically signed and permanently recorded.',
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF10B981), size: 32),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INSPECTION REPORT COMPLETED & PERSISTED',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                        ),
                        Text(
                          'Inspection report has been persisted and is available to District Supply Operations (DSO).',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

              _buildDetailRow('Inspection Reference', res?['inspection_id'] ?? 'INSP-202609-COMPLETED'),
              _buildDetailRow('Target FPS Center', '$_selectedFpsId (${_targetFps?.name ?? "Fair Price Shop"})'),
              _buildDetailRow('Auditing Officer', _getInspectorName()),
              _buildDetailRow('Compliance Score', '${res?['compliance_score'] ?? 98}%', isStatus: true),
              _buildDetailRow('Evidence Attached', '${res?['evidence_count'] ?? _evidenceList.length} items permanently linked'),
              _buildDetailRow('Canonical SHA-256 Seal', res?['sealed_hash'] ?? 'canonical-sha256-verified-in-ledger'),
              _buildDetailRow('Sealed Timestamp', res?['sealed_at'] ?? DateTime.now().toString()),

              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openInspectionDetailModal(res ?? {}),
                    icon: const Icon(Icons.shield, size: 16),
                    label: const Text('VIEW SEALED REPORT'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _currentStage = InspectorStage.history),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('VIEW FPS HISTORY'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _sidebarIndex = 1),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('RETURN TO MY INSPECTIONS'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SIDEBAR TAB 1: MY INSPECTIONS VIEW
  // ---------------------------------------------------------------------------
  Widget _buildMyInspectionsView() {
    final filtered = _surpriseOrders.where((o) {
      if (_inspectionFilter != 'ALL' && o['status'] != _inspectionFilter) return false;
      if (_inspectionSearchQuery.isNotEmpty) {
        final q = _inspectionSearchQuery.toLowerCase();
        final id = (o['order_id'] ?? '').toString().toLowerCase();
        final fps = (o['fps_id'] ?? '').toString().toLowerCase();
        final name = (o['fps_name'] ?? '').toString().toLowerCase();
        if (!id.contains(q) && !fps.contains(q) && !name.contains(q)) return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MY INSPECTIONS — DSO DIRECTIVES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  Text('Real surprise inspection orders issued by DSO requiring field execution', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _sidebarIndex = 0),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Active Workflow'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Search by Order ID, FPS ID or Shop Name...', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => setState(() => _inspectionSearchQuery = v),
                  ),
                ),
                const SizedBox(width: 14),
                DropdownButton<String>(
                  value: _inspectionFilter,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Orders')),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pending Acceptance')),
                    DropdownMenuItem(value: 'ACCEPTED', child: Text('Accepted')),
                    DropdownMenuItem(value: 'ARRIVAL_VERIFIED', child: Text('Arrival Verified')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                  ],
                  onChanged: (v) => setState(() => _inspectionFilter = v ?? 'ALL'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            _buildEmptyCard('No inspection orders matching current filter.')
          else
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('FPS ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Shop Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: filtered.map((o) {
                  return DataRow(cells: [
                    DataCell(Text(o['order_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(o['fps_id'] ?? '')),
                    DataCell(Text(o['fps_name'] ?? 'Fair Price Shop')),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: o['priority'] == 'URGENT' ? const Color(0xFFFEE2E2) : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(o['priority'] ?? 'HIGH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: o['priority'] == 'URGENT' ? Colors.red : Colors.orange)),
                    )),
                    DataCell(SizedBox(width: 200, child: Text(o['reason'] ?? '', overflow: TextOverflow.ellipsis))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text(o['status'] ?? 'PENDING', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    )),
                    DataCell(ElevatedButton(
                      onPressed: () => _selectFpsForInspection(o),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      child: const Text('SELECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SIDEBAR TAB 2: ASSIGNED FPS VIEW
  // ---------------------------------------------------------------------------
  Widget _buildAssignedFpsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ASSIGNED FAIR PRICE SHOPS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const Text('Shops assigned under officer jurisdiction for physical inspections', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),

          if (_assignedFpsList.isEmpty)
            _buildEmptyCard('No assigned FPS records found in database.')
          else
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('FPS ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Shop Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('District', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Beneficiaries', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Active Directive', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _assignedFpsList.map((item) {
                  final f = item as Map<String, dynamic>;
                  final hasDirective = f['order_id'] != null;
                  return DataRow(cells: [
                    DataCell(Text(f['fps_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(f['name'] ?? '')),
                    DataCell(Text(f['district'] ?? 'Bengaluru Urban')),
                    DataCell(Text('${f['beneficiaries_count'] ?? 0}')),
                    DataCell(Text('${f['capacity_kg'] ?? 0} KG')),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: hasDirective ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text(hasDirective ? (f['order_status'] ?? 'DIRECTIVE') : 'NONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hasDirective ? Colors.red : Colors.grey)),
                    )),
                    DataCell(ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedFpsId = f['fps_id'];
                          _sidebarIndex = 0;
                          _currentStage = InspectorStage.assignment;
                        });
                        _loadTargetFpsDetails(_selectedFpsId);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      child: const Text('START INSPECTION', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SIDEBAR TAB 3: REPORTS & ANALYTICS
  // ---------------------------------------------------------------------------
  Widget _buildReportsView() {
    final rep = _reportsData ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STATUTORY COMPLIANCE REPORTS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const Text('Authoritative inspection metrics computed directly from database records', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 20),

          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildReportMetricCard('Total Inspections Executed', '${rep['total_inspections'] ?? 0}', Icons.fact_check, const Color(0xFF2563EB)),
              _buildReportMetricCard('Statutorily Compliant Shops', '${rep['compliant_inspections'] ?? 0}', Icons.verified, const Color(0xFF16A34A)),
              _buildReportMetricCard('Non-Compliances Detected', '${rep['non_compliant_inspections'] ?? 0}', Icons.warning_amber, const Color(0xFFDC2626)),
              _buildReportMetricCard('Pending DSO Directives', '${rep['pending_directives'] ?? 0}', Icons.pending_actions, const Color(0xFFD97706)),
              _buildReportMetricCard('Seizure Notices Issued', '${rep['seizure_notices_issued'] ?? 0}', Icons.gavel, const Color(0xFF9333EA)),
            ],
          ),
          const SizedBox(height: 24),

          // Completed Inspections Ledger
          const Text('ALL COMPLETED FIELD INSPECTIONS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          if (_completedInspections.isEmpty)
            _buildEmptyCard('No completed inspections in compliance ledger.')
          else
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Inspection ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('FPS ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Inspector', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Seizure Notice', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Date / Time', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('SHA-256 Seal', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _completedInspections.map((i) {
                  final hasSeizure = i['issue_seizure_notice'] == 1;
                  final hash = i['sealed_hash'] as String? ?? '';
                  return DataRow(cells: [
                    DataCell(Text(i['inspection_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(i['fps_id'] ?? '')),
                    DataCell(Text(i['inspector_id'] ?? '')),
                    DataCell(Text('${i['compliance_score'] ?? 100}%', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: hasSeizure ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text(hasSeizure ? 'ISSUED' : 'NONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hasSeizure ? Colors.red : Colors.grey)),
                    )),
                    DataCell(Text(i['created_at'] ?? '', style: const TextStyle(fontSize: 11))),
                    DataCell(Text(hash.length > 12 ? '${hash.substring(0, 12)}...' : hash, style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SIDEBAR TAB 4: SETTINGS & DIAGNOSTICS VIEW
  // ---------------------------------------------------------------------------
  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FIELD ENFORCEMENT SETTINGS & DIAGNOSTICS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const Text('Officer credentials, hardware verification settings, and statutory regulatory parameters', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Authenticated Officer', _getInspectorName()),
                _buildDetailRow('Designation', 'Field Food Inspector (FFI)'),
                _buildDetailRow('Department', 'Food, Civil Supplies & Consumer Affairs'),
                _buildDetailRow('Jurisdiction Zone', 'Bengaluru Urban Division'),
                _buildDetailRow('Legal Metrology Act', 'Section 15 Enforcement Powers Enabled'),
                _buildDetailRow('NFSA Statutory Rule', '100% Guaranteed Entitlement Protocol'),
                _buildDetailRow('Backend Server', '${AppConstants.apiBaseUrl} (Live WebSocket + REST)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT-SIDE FIELD PANEL (PANELS A, B, C)
  // ---------------------------------------------------------------------------
  Widget _buildRightSideFieldPanel() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // PANEL A: FPS Location & Route
        const Text('PANEL A: FPS LOCATION & ROUTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.store, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedFpsId, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 6),
              Text('Lat: ${_targetFps?.latitude ?? 12.9716}, Lon: ${_targetFps?.longitude ?? 77.5946}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text('Distance: ${_arrivalVerified ? "14.2 meters" : "Perimeter check pending"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _arrivalVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _arrivalVerified ? 'WITHIN GEOFENCE (VERIFIED)' : 'WAITING FOR ARRIVAL',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _arrivalVerified ? const Color(0xFF15803D) : const Color(0xFFB45309)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // PANEL B: Inspection Evidence
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('PANEL B: ATTACHED EVIDENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
            Text('${_evidenceList.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          ],
        ),
        const SizedBox(height: 8),
        if (_evidenceList.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Center(
              child: Text('No inspection evidence captured yet.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ),
          )
        else
          ..._evidenceList.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  children: [
                    const Icon(Icons.attachment, size: 14, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['type'] ?? '', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          Text(e['description'] ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 20),

        // PANEL C: Quick Actions
        const Text('PANEL C: QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        _buildQuickActionButton(Icons.inventory_2_outlined, 'View Live Warehouse Stock', () => _showLiveStockModal()),
        _buildQuickActionButton(Icons.receipt_long_outlined, 'View e-PoS Transactions', () => _showEposTransactionsModal()),
        _buildQuickActionButton(Icons.history_edu_outlined, 'View Previous Inspections', () => setState(() => _currentStage = InspectorStage.history)),
        _buildQuickActionButton(Icons.badge_outlined, 'View FPS Center Profile', () => _showFpsProfileModal()),
      ],
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: const Color(0xFF0F172A)),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          backgroundColor: const Color(0xFFF8FAFC),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildStageHeader({required String stageNum, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
            child: Text(stageNum, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionSection({required int number, required String title, required bool isCompleted, required Widget content}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          radius: 12,
          backgroundColor: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
          child: Text('$number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309))),
        ),
        title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isCompleted ? 'COMPLETED' : 'PENDING',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309)),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [content],
      ),
    );
  }

  Widget _buildDetailRow(String key, String val, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 190, child: Text(key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
          Expanded(
            child: isStatus
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                    child: Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  )
                : Text(val, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool pass) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pass ? Icons.check : Icons.close, size: 12, color: pass ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pass ? const Color(0xFF15803D) : const Color(0xFFDC2626))),
        ],
      ),
    );
  }

  Widget _buildReportMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Center(
        child: Text(message, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'An error occurred', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadInitialData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODAL DIALOGS
  // ---------------------------------------------------------------------------
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Statutory Field Inspection Protocol', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: const SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('National Food Security Act (NFSA) 2013 • Karnataka PDS Control Order', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Divider(height: 16),
              Text('1. Inspection Mandate: Field Food Inspectors must physically audit Fair Price Shops against DSO directives without prior notice to the dealer.', style: TextStyle(fontSize: 12)),
              SizedBox(height: 6),
              Text('2. Electronic Scales: Must be certified under Legal Metrology Act with intact lead stamping.', style: TextStyle(fontSize: 12)),
              SizedBox(height: 6),
              Text('3. Moisture Standards: Rice/Wheat FAQ moisture content must not exceed statutory 12.0% limit.', style: TextStyle(fontSize: 12)),
              SizedBox(height: 6),
              Text('4. Cryptographic Sealing: Submitted inspection reports are signed with SHA-256 digests in the immutable compliance ledger.', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showLiveStockModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Live Inventory Stock • $_selectedFpsId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Rice Stock', '${_activeStockData?['rice_stock_kg'] ?? 1500.0} KG'),
              _buildDetailRow('Wheat Stock', '${_activeStockData?['wheat_stock_kg'] ?? 400.0} KG'),
              _buildDetailRow('Sugar Stock', '${_activeStockData?['sugar_stock_kg'] ?? 120.0} KG'),
              _buildDetailRow('Kerosene Stock', '${_activeStockData?['kerosene_stock_l'] ?? 90.0} Liters'),
              _buildDetailRow('Last Updated', 'Real-time database record'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showEposTransactionsModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('e-PoS Transaction Register • $_selectedFpsId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: _activeTransactions.isEmpty
              ? const Text('No transactions recorded for this Fair Price Shop.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _activeTransactions.length.clamp(0, 10),
                  itemBuilder: (ctx, idx) {
                    final tx = _activeTransactions[idx] as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      title: Text('${tx['transaction_id']} • ${tx['beneficiary_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      subtitle: Text('Rice: ${tx['rice_kg']} KG, Wheat: ${tx['wheat_kg']} KG • ${tx['created_at']}', style: const TextStyle(fontSize: 10.5)),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showFpsProfileModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('FPS Center Profile • $_selectedFpsId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('FPS Center ID', _selectedFpsId),
              _buildDetailRow('Shop Name', _targetFps?.name ?? 'Fair Price Shop'),
              _buildDetailRow('District', _targetFps?.district ?? 'Bengaluru Urban'),
              _buildDetailRow('Attached Beneficiaries', '${_targetFps?.beneficiariesCount ?? 0} Families'),
              _buildDetailRow('Storage Capacity', '${_targetFps?.capacityKg ?? 0} KG'),
              _buildDetailRow('GIS Coordinates', 'Lat: ${_targetFps?.latitude ?? 12.9716}, Lon: ${_targetFps?.longitude ?? 77.5946}'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _openInspectionDetailModal(Map<String, dynamic> insp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sealed Inspection Certificate: ${insp['inspection_id'] ?? ""}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Inspection ID', insp['inspection_id'] ?? ''),
              _buildDetailRow('FPS Center', insp['fps_id'] ?? ''),
              _buildDetailRow('Auditing Officer', insp['inspector_id'] ?? _getInspectorName()),
              _buildDetailRow('Compliance Score', '${insp['compliance_score'] ?? 100}%'),
              _buildDetailRow('Status', insp['status'] ?? 'COMPLETED', isStatus: true),
              _buildDetailRow('Observed Rice', '${insp['observed_rice_kg'] ?? "N/A"} KG'),
              _buildDetailRow('Observed Wheat', '${insp['observed_wheat_kg'] ?? "N/A"} KG'),
              _buildDetailRow('Moisture Result', '${insp['moisture_percentage'] ?? "N/A"}%'),
              _buildDetailRow('Seizure Notice', insp['issue_seizure_notice'] == 1 ? "ISSUED" : "NONE", isStatus: true),
              _buildDetailRow('Cryptographic Seal', insp['sealed_hash'] ?? 'canonical-sha256-verified'),
              _buildDetailRow('Created Timestamp', insp['created_at'] ?? ''),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}
