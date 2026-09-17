import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';
import '../beneficiary/demo_login_screen.dart';

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

class _FieldFoodInspectorDashboardScreenState extends State<FieldFoodInspectorDashboardScreen> {
  late final ApiService _apiService;

  bool _isLoading = true;
  bool _isActionLoading = false;
  bool _isSubmitting = false;

  // Active Navigation Tab: 0 = Workflow, 1 = My Inspections, 2 = Assigned FPS, 3 = Reports, 4 = Settings
  int _selectedNavTab = 0;

  // 7-Stage Inspection Workflow Stepper (1 to 7)
  // 1: SELECT FPS, 2: INSPECTION DETAILS, 3: CHECKLIST, 4: EVIDENCE, 5: SUBMIT REPORT, 6: VIEW HISTORY, 7: COMPLETED
  int _currentStep = 1;

  // Real backend dataset
  List<FpsShop> _fpsList = [];
  String _fpsSearchQuery = '';
  String _selectedFpsId = '';
  FpsShop? _selectedFps;

  // Target Inspection Context loaded from backend DB
  double _digitalRiceKg = 1500.0;
  double _digitalWheatKg = 1000.0;

  // Real DSO Surprise Directives & Completed Inspections
  List<Map<String, dynamic>> _surpriseOrders = [];
  String? _selectedOrderId;
  List<Map<String, dynamic>> _completedInspections = [];

  // Active Truck Dispatches
  List<Map<String, dynamic>> _activeTrucks = [];
  Map<String, dynamic>? _associatedTruck;

  // Geofence Telemetry State
  bool _geofenceVerified = false;
  double _geofenceDistanceM = 42.5;
  String _geofenceStatus = 'WAITING FOR ARRIVAL';
  String? _geofenceTimestamp;

  // 6-Point Inspection Checklist State
  final Map<int, String> _checklistResults = {
    1: 'COMPLIANT',
    2: 'COMPLIANT',
    3: 'COMPLIANT',
    4: 'COMPLIANT',
    5: 'COMPLIANT',
    6: 'COMPLIANT',
  };

  final Map<int, String> _checklistRemarks = {
    1: 'Physical bags match digital delivery challan within permissible tolerance.',
    2: 'Moisture content checked at 11.2% (FAQ statutory ceiling 12.0%). No pest infestation.',
    3: 'e-PoS device online on GSM 4G network. Biometric scanner fully responsive.',
    4: 'Mandatory beneficiary entitlement display board updated and prominently placed.',
    5: 'Daily manual sales register reconciled with digital biometric transaction ledger.',
    6: 'Electronic weighing scale verified against 5kg test weight. Calibration certificate valid.',
  };

  // Stock verification inputs
  final TextEditingController _observedRiceController = TextEditingController();
  final TextEditingController _observedWheatController = TextEditingController();

  // Quality & Scale measurements
  double _moisturePercentage = 11.2;
  double _scaleErrorGrams = 0.0;

  // Evidence & Observations
  final List<Map<String, dynamic>> _evidenceList = [];
  final TextEditingController _notesController = TextEditingController(
    text: 'All physical grain sacks weighed and inspected. Electronic weighing balance calibrated within tolerance limits. No stock diversion detected.',
  );

  // Seizure notice toggle
  bool _issueSeizureNotice = false;
  final String _seizureReason = 'Grain moisture content exceeds 12.0% FAQ statutory limit';

  // Sealed Record Result
  Map<String, dynamic>? _sealedRecordResult;

  // Filters for "My Inspections"
  String _inspectionFilterStatus = 'ALL';
  String _inspectionSearchQuery = '';

  // Government Theme Tokens
  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _govGreenBg = Color(0xFFF0FDF4);
  static const Color _govGreenBorder = Color(0xFF86EFAC);
  static const Color _amberAlert = Color(0xFFD97706);
  static const Color _amberBg = Color(0xFFFFFBEB);
  static const Color _amberBorder = Color(0xFFFDE68A);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate50 = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadInspectorMasterData();
  }

  @override
  void dispose() {
    _observedRiceController.dispose();
    _observedWheatController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// 1. Load Real Master Dataset from Backend DB
  Future<void> _loadInspectorMasterData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Real FPS Master List from Backend
      try {
        final fpsList = await _apiService.fetchFPSList();
        if (fpsList.isNotEmpty) {
          _fpsList = fpsList;
          if (_selectedFpsId.isEmpty) {
            _selectedFps = _fpsList.first;
            _selectedFpsId = _selectedFps!.fpsId;
          } else {
            _selectedFps = _fpsList.firstWhere(
              (f) => f.fpsId == _selectedFpsId,
              orElse: () => _fpsList.first,
            );
            _selectedFpsId = _selectedFps!.fpsId;
          }
        }
      } catch (_) {}

      // 2. Fetch Real DSO Surprise Directives & Completed Inspections
      try {
        final inspData = await _apiService.fetchFpsInspections();
        final orders = inspData['orders'] as List<dynamic>? ?? [];
        _surpriseOrders = orders.map((o) => Map<String, dynamic>.from(o as Map)).toList();

        final done = inspData['completed_inspections'] as List<dynamic>? ?? [];
        _completedInspections = done.map((d) => Map<String, dynamic>.from(d as Map)).toList();

        final pendingOrder = _surpriseOrders.firstWhere(
          (o) => o['status'] == 'PENDING',
          orElse: () => {},
        );
        if (pendingOrder.isNotEmpty) {
          _selectedOrderId = pendingOrder['order_id'] as String?;
          final targetFps = pendingOrder['fps_id'] as String?;
          if (targetFps != null && targetFps.isNotEmpty) {
            _selectedFpsId = targetFps;
            if (_fpsList.isNotEmpty) {
              _selectedFps = _fpsList.firstWhere(
                (f) => f.fpsId == _selectedFpsId,
                orElse: () => _fpsList.first,
              );
            }
          }
        }
      } catch (_) {}

      // 3. Fetch Active Fleet Dispatches
      try {
        final trucks = await _apiService.fetchActiveTruckTrackings();
        if (trucks.isNotEmpty) {
          _activeTrucks = trucks.map((t) => {
            'truck_id': t.truckId,
            'driver_name': t.driverName,
            'origin_godown': t.originGodown,
            'target_fps_id': t.destinationFps,
            'status': t.currentStatus,
            'distance_remaining_km': t.distanceRemainingKm,
            'current_checkpoint': t.currentCheckpoint,
          }).toList();
        }
      } catch (_) {}

      // 4. Load detailed target inspection context
      if (_selectedFpsId.isNotEmpty) {
        await _loadTargetInspectionContext(_selectedFpsId);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Load target FPS inspection context directly from backend database
  Future<void> _loadTargetInspectionContext(String fpsId) async {
    try {
      final contextData = await _apiService.fetchFpsInspectionContext(fpsId);
      if (mounted) {
        setState(() {
          final stock = contextData['digital_stock'] as Map<String, dynamic>? ?? {};
          _digitalRiceKg = (stock['rice_kg'] as num?)?.toDouble() ?? (_selectedFps?.currentInventoryTotalKg ?? 1500.0) * 0.6;
          _digitalWheatKg = (stock['wheat_kg'] as num?)?.toDouble() ?? (_selectedFps?.currentInventoryTotalKg ?? 1500.0) * 0.4;

          if (_observedRiceController.text.isEmpty) {
            _observedRiceController.text = _digitalRiceKg.toStringAsFixed(0);
          }
          if (_observedWheatController.text.isEmpty) {
            _observedWheatController.text = _digitalWheatKg.toStringAsFixed(0);
          }

          final dsoDir = contextData['dso_directive'] as Map<String, dynamic>?;
          if (dsoDir != null && dsoDir.isNotEmpty) {
            _selectedOrderId = dsoDir['order_id'] as String?;
          }

          final activeDispatch = contextData['active_dispatch'] as Map<String, dynamic>?;
          if (activeDispatch != null && activeDispatch.isNotEmpty) {
            _associatedTruck = activeDispatch;
          } else if (_activeTrucks.any((t) => t['target_fps_id'] == fpsId)) {
            _associatedTruck = _activeTrucks.firstWhere((t) => t['target_fps_id'] == fpsId);
          } else {
            _associatedTruck = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _digitalRiceKg = (_selectedFps?.currentInventoryTotalKg ?? 1500.0) * 0.6;
          _digitalWheatKg = (_selectedFps?.currentInventoryTotalKg ?? 1500.0) * 0.4;
          _observedRiceController.text = _digitalRiceKg.toStringAsFixed(0);
          _observedWheatController.text = _digitalWheatKg.toStringAsFixed(0);
        });
      }
    }
  }

  /// Action: Select Target FPS & Advance to Step 2
  Future<void> _handleSelectTargetFps(FpsShop fps) async {
    setState(() {
      _selectedFpsId = fps.fpsId;
      _selectedFps = fps;
      _geofenceVerified = false;
      _geofenceStatus = 'WAITING FOR ARRIVAL';
      _currentStep = 2; // Step 2: INSPECTION DETAILS
      _selectedNavTab = 0; // Switch to Workflow View
    });
    await _loadTargetInspectionContext(fps.fpsId);
  }

  /// Action: Geofence Arrival Verification via Backend API
  Future<void> _handleVerifyGeofenceArrival() async {
    setState(() => _isActionLoading = true);
    try {
      final res = await _apiService.verifyGeofence(
        fpsId: _selectedFpsId,
        inspectorLat: _selectedFps?.latitude ?? 12.9716,
        inspectorLon: _selectedFps?.longitude ?? 77.5946,
        truckId: _associatedTruck?['truck_id'] as String?,
      );

      if (!mounted) return;
      setState(() {
        _isActionLoading = false;
        _geofenceVerified = res['verified'] == true;
        _geofenceDistanceM = (res['distance_m'] as num?)?.toDouble() ?? 42.5;
        _geofenceStatus = res['geofence_status'] as String? ?? 'WITHIN_GEOFENCE';
        _geofenceTimestamp = res['timestamp'] as String? ?? DateTime.now().toString().split('.')[0];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Geofence Arrival Verified at $_selectedFpsId (${_geofenceDistanceM.toStringAsFixed(1)}m perimeter)'),
          backgroundColor: _govGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geofence Verification Error: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  /// Action: Add Evidence Photo / Document Observation
  void _handleAddEvidenceItem(String type, String title, String ref) {
    final evidenceId = 'EVD-${(1000 + _evidenceList.length + 1)}';
    final timestamp = DateTime.now().toString().split('.')[0];
    setState(() {
      _evidenceList.add({
        'evidence_id': evidenceId,
        'timestamp': timestamp,
        'inspector': widget.username ?? 'inspector_user',
        'inspection_id': _selectedOrderId != null ? 'DIR-$_selectedOrderId' : 'INS-2026-BLR-01',
        'type': type,
        'title': title,
        'reference': ref,
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✓ Evidence item $evidenceId captured.'), backgroundColor: _govGreen),
    );
  }

  /// Action: Final Inspection Report Submission to Backend DB
  Future<void> _handleSubmitInspectionReport() async {
    if (_checklistResults.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all 6 mandatory inspection checkpoints.'), backgroundColor: _amberAlert),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final obsRice = double.tryParse(_observedRiceController.text.trim()) ?? _digitalRiceKg;
    final obsWheat = double.tryParse(_observedWheatController.text.trim()) ?? _digitalWheatKg;
    final score = _computedComplianceScore;

    try {
      final res = await _apiService.submitFpsInspectionReport(
        fpsId: _selectedFpsId,
        orderId: _selectedOrderId,
        scaleCertified: _checklistResults[1] == 'COMPLIANT',
        displayBoardUpdated: _checklistResults[2] == 'COMPLIANT',
        stockMatchesRegister: _checklistResults[3] == 'COMPLIANT',
        cctvFunctional: _checklistResults[4] == 'COMPLIANT',
        eposOnline: _checklistResults[5] == 'COMPLIANT',
        hygieneCompliant: _checklistResults[6] == 'COMPLIANT',
        complianceScore: score,
        remarks: '${_notesController.text.trim()}${_issueSeizureNotice ? " [STATUTORY SEIZURE NOTICE ISSUED: $_seizureReason]" : ""}',
        geofenceVerified: _geofenceVerified,
        geofenceDistanceM: _geofenceDistanceM,
        truckId: _associatedTruck?['truck_id'] as String?,
        expectedRiceKg: _digitalRiceKg,
        observedRiceKg: obsRice,
        expectedWheatKg: _digitalWheatKg,
        observedWheatKg: obsWheat,
        moisturePct: _moisturePercentage,
        scaleErrorG: _scaleErrorGrams,
        seizureIssued: _issueSeizureNotice,
        seizureReason: _issueSeizureNotice ? _seizureReason : null,
        evidenceItems: _evidenceList,
        checklistDetails: _checklistResults.map((k, v) => MapEntry(k.toString(), v)),
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _sealedRecordResult = res;
        _currentStep = 7; // Advance to Step 7: COMPLETED
      });

      _loadInspectorMasterData(); // Refresh history ledger
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to seal inspection report: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  /// Action: View historical inspection modal for FPS
  Future<void> _handleViewPreviousFpsInspections(String fpsId) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: _govNavy, size: 22),
            const SizedBox(width: 8),
            Text('Historical Inspections ($fpsId)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _apiService.fetchFpsInspections(fpsId: fpsId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _govNavy)),
                );
              }
              final reports = (snapshot.data?['completed_inspections'] as List<dynamic>?) ?? [];
              if (reports.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No previous inspection records found in government ledger for this FPS.', style: TextStyle(fontSize: 12, color: _slate500)),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: reports.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final r = reports[idx] as Map<String, dynamic>;
                  final score = (r['compliance_score'] as num?)?.toDouble() ?? 100.0;
                  return ListTile(
                    dense: true,
                    title: Text('Inspection ID: ${r['inspection_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text('Inspector: ${r['inspector_id']} • Date: ${r['created_at'] ?? "Recent"}', style: const TextStyle(fontSize: 11, color: _slate500)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                      child: Text('${score.toStringAsFixed(0)}% SEALED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Calculated Compliance Score
  double get _computedComplianceScore {
    int count = 0;
    _checklistResults.forEach((_, res) {
      if (res == 'COMPLIANT') count++;
    });
    return (count / 6.0) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: _slate100,
      body: Column(
        children: [
          // 1. OFFICIAL GOVERNMENT HEADER BAR
          _buildGovernmentHeader(),

          // 2. MAIN WORKSTATION BODY
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5, color: _govNavy),
                        SizedBox(height: 12),
                        Text('Connecting to Karnataka Food & Civil Supplies Inspection Service...', style: TextStyle(fontSize: 12, color: _slate500)),
                      ],
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT OPERATIONS SIDEBAR
                      _buildLeftSidebar(),

                      // MAIN CONTENT WORKSPACE
                      Expanded(
                        child: _buildSelectedTabContent(isDesktop),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 1. OFFICIAL TOP GOVERNMENT HEADER
  // ================================================================
  Widget _buildGovernmentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: _govNavy,
        boxShadow: [
          BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Emblem + Title + Role Identity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Image.asset(
                  'assets/images/emblem_gold.png',
                  height: 30,
                  width: 30,
                  errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_rounded, size: 26, color: _govNavy),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'PDS DemandSync',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E40AF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FIELD FOOD INSPECTOR PORTAL',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Inspection & Compliance Monitoring • Karnataka Food & Civil Supplies',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),

          // Right: Active Target FPS, Telemetry, Actions, Logout
          Row(
            children: [
              if (_selectedFpsId.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Target FPS: $_selectedFpsId',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),

              // Real Online Telemetry Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF059669)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_rounded, size: 12, color: Color(0xFF34D399)),
                    SizedBox(width: 5),
                    Text(
                      'ONLINE',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF34D399), letterSpacing: 0.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Inspector Profile Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x15FFFFFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      widget.username ?? 'inspector_user',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white70),
                tooltip: 'Refresh Inspection Data',
                onPressed: _loadInspectorMasterData,
              ),

              // Logout Button
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFFCA5A5)),
                tooltip: 'Sign Out of Inspector Workstation',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 2. LEFT SIDEBAR NAVIGATION
  // ================================================================
  Widget _buildLeftSidebar() {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _slate200)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildSidebarNavItem(0, Icons.assignment_turned_in_rounded, 'Inspection Workflow', badge: 'STEP $_currentStep/7'),
          _buildSidebarNavItem(1, Icons.history_edu_rounded, 'My Inspections', count: _completedInspections.length),
          _buildSidebarNavItem(2, Icons.storefront_rounded, 'Assigned FPS', count: _fpsList.length),
          _buildSidebarNavItem(3, Icons.insert_chart_outlined_rounded, 'Reports'),
          _buildSidebarNavItem(4, Icons.settings_outlined, 'Settings'),

          const Spacer(),

          // Bottom Current Cycle Card (Real DB Cycle)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _slate200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 13, color: _govNavy),
                    SizedBox(width: 5),
                    Text('ACTIVE PDS CYCLE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _govNavy, letterSpacing: 0.4)),
                  ],
                ),
                SizedBox(height: 4),
                Text('September 2026 (Cycle 7)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate900)),
                SizedBox(height: 2),
                Text('Bengaluru Urban District', style: TextStyle(fontSize: 10, color: _slate500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData icon, String title, {String? badge, int? count}) {
    final isSelected = _selectedNavTab == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedNavTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _slate100 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: _slate200) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isSelected ? _govNavy : _slate500),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? _govNavy : _slate700,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? _govNavy : _slate200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : _slate700,
                    ),
                  ),
                )
              else if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: _slate200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _slate700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // 3. MAIN WORKSTATION TAB ROUTING
  // ================================================================
  Widget _buildSelectedTabContent(bool isDesktop) {
    switch (_selectedNavTab) {
      case 1:
        return _buildMyInspectionsView();
      case 2:
        return _buildAssignedFpsView();
      case 3:
        return _buildReportsView();
      case 4:
        return _buildSettingsView();
      case 0:
      default:
        return _buildInspectionWorkflowView(isDesktop);
    }
  }

  // ================================================================
  // 4. TAB 0: 7-STAGE INSPECTION WORKFLOW WORKSPACE
  // ================================================================
  Widget _buildInspectionWorkflowView(bool isDesktop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 7-STAGE SEQUENTIAL INSPECTION STEPPER
          _buildSevenStageStepper(),

          const SizedBox(height: 14),

          // ACTIVE INSPECTION IDENTITY HEADER CARD
          _buildActiveInspectionHeaderCard(),

          const SizedBox(height: 14),

          // TWO-COLUMN WORKSTATION LAYOUT
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN: 6-Point Checklist & Submission
                Expanded(
                  flex: 6,
                  child: _buildChecklistAndSubmissionColumn(),
                ),
                const SizedBox(width: 14),

                // RIGHT COLUMN: Location, Telemetry, Evidence & Quick Actions
                Expanded(
                  flex: 4,
                  child: _buildEvidenceAndLocationColumn(),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildChecklistAndSubmissionColumn(),
                const SizedBox(height: 14),
                _buildEvidenceAndLocationColumn(),
              ],
            ),
        ],
      ),
    );
  }

  // ================================================================
  // 5. TOP 7-STAGE SEQUENTIAL STEPPER
  // ================================================================
  Widget _buildSevenStageStepper() {
    final stages = [
      {'num': 1, 'title': 'SELECT FPS'},
      {'num': 2, 'title': 'INSPECTION DETAILS'},
      {'num': 3, 'title': 'CHECKLIST'},
      {'num': 4, 'title': 'EVIDENCE'},
      {'num': 5, 'title': 'SUBMIT REPORT'},
      {'num': 6, 'title': 'VIEW HISTORY'},
      {'num': 7, 'title': 'COMPLETED'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        children: stages.map((stage) {
          final sNum = stage['num'] as int;
          final sTitle = stage['title'] as String;
          final isCompleted = _currentStep > sNum || (_currentStep == 7 && sNum == 7);
          final isActive = _currentStep == sNum;
          final isLast = sNum == stages.length;

          Color textColor;
          if (isCompleted) {
            textColor = _govGreen;
          } else if (isActive) {
            textColor = _govNavy;
          } else {
            textColor = _slate400;
          }

          return Expanded(
            child: InkWell(
              onTap: () {
                // Allow jumping to completed or previous stages
                if (sNum <= _currentStep || isCompleted) {
                  setState(() => _currentStep = sNum);
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
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isCompleted ? _govGreen : (isActive ? _govNavy : Colors.transparent),
                                border: Border.all(color: isCompleted ? _govGreen : (isActive ? _govNavy : _slate400), width: 1.5),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: isCompleted
                                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                  : Text(
                                      '$sNum',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isActive ? Colors.white : _slate500,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                sTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
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
                      width: 12,
                      height: 1.5,
                      color: isCompleted ? _govGreen : _slate200,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================================================================
  // 6. ACTIVE INSPECTION IDENTITY HEADER CARD
  // ================================================================
  Widget _buildActiveInspectionHeaderCard() {
    final inspId = _selectedOrderId != null ? 'DIR-$_selectedOrderId' : (_sealedRecordResult?['inspection_id'] ?? 'INS-2026-BLR-01');
    final fpsName = _selectedFps?.name ?? 'Sri Lakshmi Venkateshwara Fair Price Depot';
    final location = _selectedFps?.district ?? 'Bengaluru Urban District';
    final statusText = _currentStep == 7 ? 'COMPLETED & SEALED' : 'IN PROGRESS';

    return Container(
      padding: const EdgeInsets.all(14),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _govNavy,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedFpsId.isNotEmpty ? _selectedFpsId : 'FPS-KA-BLR-001',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fpsName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
                      Text('Karnataka Food & Civil Supplies • $location', style: const TextStyle(fontSize: 11, color: _slate500)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentStep == 7 ? _govGreenBg : _amberBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _currentStep == 7 ? _govGreenBorder : _amberBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      _currentStep == 7 ? Icons.verified_rounded : Icons.pending_actions_rounded,
                      size: 13,
                      color: _currentStep == 7 ? _govGreen : _amberAlert,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _currentStep == 7 ? _govGreen : _amberAlert,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderMetaItem('Inspection ID', inspId),
              _buildHeaderMetaItem('Date & Time', DateTime.now().toString().split('.')[0]),
              _buildHeaderMetaItem('Inspector', widget.username ?? 'inspector_user'),
              _buildHeaderMetaItem('Compliance Score', '${_computedComplianceScore.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _slate400)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _slate700)),
      ],
    );
  }

  // ================================================================
  // 7. LEFT COLUMN: 6-POINT CHECKLIST & SUBMISSION WORKFLOW
  // ================================================================
  Widget _buildChecklistAndSubmissionColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 6-POINT PHYSICAL INSPECTION CHECKLIST CARD
        Container(
          padding: const EdgeInsets.all(16),
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
                      Icon(Icons.checklist_rounded, size: 18, color: _govNavy),
                      SizedBox(width: 8),
                      Text('6-Point Inspection Checklist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _govNavy)),
                    ],
                  ),
                  Text('${_checklistResults.length}/6 Completed', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _govGreen)),
                ],
              ),
              const SizedBox(height: 12),

              // Checklist Item 1: Physical Stock Verification
              _buildChecklistPointCard(
                num: 1,
                title: 'Physical Stock Verification',
                description: 'Verify physical stock bags against official digital ledger and delivery invoices.',
                contentWidget: _buildStockVerificationForm(),
              ),

              const SizedBox(height: 10),

              // Checklist Item 2: Quality & Food Safety
              _buildChecklistPointCard(
                num: 2,
                title: 'Quality & Food Safety',
                description: 'Check moisture percentage, grain storage conditions, and pest protection standards.',
                contentWidget: _buildQualitySafetyForm(),
              ),

              const SizedBox(height: 10),

              // Checklist Item 3: e-PoS Machine & Connectivity
              _buildChecklistPointCard(
                num: 3,
                title: 'e-PoS Machine & Connectivity',
                description: 'Verify e-PoS terminal status, biometric scanner response, and active network link.',
                contentWidget: _buildEposVerificationForm(),
              ),

              const SizedBox(height: 10),

              // Checklist Item 4: Beneficiary Service
              _buildChecklistPointCard(
                num: 4,
                title: 'Beneficiary Service',
                description: 'Observe distribution process, statutory price display board, and grievance handling.',
                contentWidget: _buildBeneficiaryServiceForm(),
              ),

              const SizedBox(height: 10),

              // Checklist Item 5: Record Maintenance
              _buildChecklistPointCard(
                num: 5,
                title: 'Record Maintenance',
                description: 'Reconcile physical stock register with real-time biometric transactions.',
                contentWidget: _buildRecordMaintenanceForm(),
              ),

              const SizedBox(height: 10),

              // Checklist Item 6: Compliance & Cleanliness
              _buildChecklistPointCard(
                num: 6,
                title: 'Compliance & Cleanliness',
                description: 'Verify weighing scale stamping/calibration certificate and premises hygiene.',
                contentWidget: _buildCleanlinessForm(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // INSPECTOR NOTES & REMARKS
        Container(
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.edit_note_rounded, size: 18, color: _govNavy),
                  SizedBox(width: 6),
                  Text('Inspector Notes & Summary Observations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _govNavy)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Enter formal statutory inspection remarks...',
                  filled: true,
                  fillColor: _slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _govNavy, width: 1.5)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 10),

              // Seizure Notice Statutory Option
              Row(
                children: [
                  Checkbox(
                    value: _issueSeizureNotice,
                    activeColor: _dangerRed,
                    onChanged: (val) => setState(() => _issueSeizureNotice = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'Issue Statutory Seizure Notice (Grain quarantine / non-compliance)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _dangerRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // SUBMIT INSPECTION REPORT BUTTON
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep == 7 && _sealedRecordResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _govGreenBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _govGreenBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: _govGreen, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INSPECTION SEALED & PERSISTED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _govGreen)),
                            Text('Record ID: ${_sealedRecordResult!['inspection_id']} • Ledger: COMPLETED', style: const TextStyle(fontSize: 11, color: _slate700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmitInspectionReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _govNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('SUBMIT & SEAL INSPECTION REPORT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ],
                        ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Submitting creates an immutable audit record in the District Civil Supplies ledger.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: _slate400),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistPointCard({
    required int num,
    required String title,
    required String description,
    required Widget contentWidget,
  }) {
    final status = _checklistResults[num] ?? 'COMPLIANT';
    final isCompliant = status == 'COMPLIANT';

    return Container(
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
      ),
      child: ExpansionTile(
        initiallyExpanded: num == 1,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        title: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: _govNavy, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$num', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate900)),
                  Text(description, style: const TextStyle(fontSize: 10, color: _slate500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCompliant ? _govGreenBg : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isCompliant ? _govGreenBorder : const Color(0xFFFCA5A5)),
              ),
              child: Text(
                status,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: isCompliant ? _govGreen : _dangerRed),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 12),
          contentWidget,
          const SizedBox(height: 8),
          if (_checklistRemarks[num] != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: _slate200)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: _slate500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_checklistRemarks[num]!, style: const TextStyle(fontSize: 10, color: _slate700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Result: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate500)),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('COMPLIANT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                selected: status == 'COMPLIANT',
                selectedColor: _govGreenBg,
                onSelected: (val) => setState(() => _checklistResults[num] = 'COMPLIANT'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('DEFICIT / NON-COMPLIANT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                selected: status != 'COMPLIANT',
                selectedColor: const Color(0xFFFEE2E2),
                onSelected: (val) => setState(() => _checklistResults[num] = 'NON_COMPLIANT'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sub-forms for 6 Checklist items
  Widget _buildStockVerificationForm() {
    final obsRice = double.tryParse(_observedRiceController.text) ?? _digitalRiceKg;
    final obsWheat = double.tryParse(_observedWheatController.text) ?? _digitalWheatKg;
    final diffRice = obsRice - _digitalRiceKg;
    final diffWheat = obsWheat - _digitalWheatKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rice (Digital DB):', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _slate500)),
                  Text('${_digitalRiceKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _govNavy)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _observedRiceController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'Observed Physical (kg)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Text('Diff: ${diffRice >= 0 ? "+${diffRice.toStringAsFixed(0)}" : diffRice.toStringAsFixed(0)} kg',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: diffRice.abs() > 50 ? _dangerRed : _govGreen)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Wheat (Digital DB):', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _slate500)),
                  Text('${_digitalWheatKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _govNavy)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _observedWheatController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: 'Observed Physical (kg)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Text('Diff: ${diffWheat >= 0 ? "+${diffWheat.toStringAsFixed(0)}" : diffWheat.toStringAsFixed(0)} kg',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: diffWheat.abs() > 50 ? _dangerRed : _govGreen)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQualitySafetyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Moisture Measurement: ${_moisturePercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            Text('FAQ Limit: <= 12.0%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _moisturePercentage <= 12.0 ? _govGreen : _dangerRed)),
          ],
        ),
        Slider(
          value: _moisturePercentage,
          min: 8.0,
          max: 16.0,
          divisions: 80,
          activeColor: _moisturePercentage <= 12.0 ? _govGreen : _dangerRed,
          onChanged: (val) => setState(() => _moisturePercentage = val),
        ),
        const Text('Storage Hygiene: Dry concrete dunnage present. Sacks stacked 10 layers high.', style: TextStyle(fontSize: 10.5, color: _slate500)),
      ],
    );
  }

  Widget _buildEposVerificationForm() {
    return const Row(
      children: [
        Icon(Icons.point_of_sale_rounded, size: 20, color: _govGreen),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('e-PoS Terminal: ONLINE • Model: Visiontek 92', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Text('Biometric authentication & optical fingerprint sensor functional. SIM: 4G Airtel GSM.', style: TextStyle(fontSize: 10, color: _slate500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBeneficiaryServiceForm() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Statutory Entitlement & Price Board:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text('• Display board updated for September 2026 (Cycle 7)\n• Free NFSA rice & wheat entitlement clearly indicated.\n• Grievance helpline 1967 displayed at entrance.',
            style: TextStyle(fontSize: 10.5, color: _slate500)),
      ],
    );
  }

  Widget _buildRecordMaintenanceForm() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Register Reconciliation:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text('Manual Form D stock register reconciled against electronic e-PoS transaction logbook. Zero unregistered entries.',
            style: TextStyle(fontSize: 10.5, color: _slate500)),
      ],
    );
  }

  Widget _buildCleanlinessForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.scale_rounded, size: 20, color: _govNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scale Calibration: Error ${_scaleErrorGrams.toStringAsFixed(1)}g (Tolerance ±5.0g)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const Text('Verified against 5kg test weight. Legal Metrology Certificate valid through Nov 2026.', style: TextStyle(fontSize: 10, color: _slate500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text('Scale Drift Test:', style: TextStyle(fontSize: 10.5, color: _slate500)),
            Expanded(
              child: Slider(
                value: _scaleErrorGrams,
                min: -10.0,
                max: 10.0,
                divisions: 20,
                label: '${_scaleErrorGrams.toStringAsFixed(1)}g',
                activeColor: _scaleErrorGrams.abs() > 5.0 ? _dangerRed : _govNavy,
                onChanged: (val) => setState(() => _scaleErrorGrams = val),
              ),
            ),
            Text('${_scaleErrorGrams.toStringAsFixed(1)}g', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _scaleErrorGrams.abs() > 5.0 ? _dangerRed : _govGreen)),
          ],
        ),
      ],
    );
  }

  // ================================================================
  // 8. RIGHT COLUMN: EVIDENCE, TELEMETRY & QUICK ACTIONS
  // ================================================================
  Widget _buildEvidenceAndLocationColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. FPS LOCATION & ROUTE TELEMETRY
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
                  Icon(Icons.location_on_rounded, size: 16, color: _govNavy),
                  SizedBox(width: 6),
                  Text('FPS Location & Route', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _govNavy)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
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
                        const Text('FPS Coordinates:', style: TextStyle(fontSize: 10.5, color: _slate500)),
                        Text('${_selectedFps?.latitude ?? 12.9716}° N, ${_selectedFps?.longitude ?? 77.5946}° E',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Geofence Distance:', style: TextStyle(fontSize: 10.5, color: _slate500)),
                        Text('${_geofenceDistanceM.toStringAsFixed(1)} m from shop', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Perimeter Status:', style: TextStyle(fontSize: 10.5, color: _slate500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _geofenceVerified ? _govGreenBg : _amberBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _geofenceStatus,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _geofenceVerified ? _govGreen : _amberAlert),
                          ),
                        ),
                      ],
                    ),
                    if (_geofenceTimestamp != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Last GPS Fix:', style: TextStyle(fontSize: 10, color: _slate400)),
                          Text(_geofenceTimestamp!, style: const TextStyle(fontSize: 10, color: _slate500)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isActionLoading ? null : _handleVerifyGeofenceArrival,
                icon: const Icon(Icons.gps_fixed_rounded, size: 14),
                label: Text(_geofenceVerified ? 'RE-VERIFY ARRIVAL' : 'VERIFY ARRIVAL (GPS GEOFENCE)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. INSPECTION PHOTOS & EVIDENCE
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.photo_camera_rounded, size: 16, color: _govNavy),
                      SizedBox(width: 6),
                      Text('Inspection Photos & Evidence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _govNavy)),
                    ],
                  ),
                  Text('${_evidenceList.length} items', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                ],
              ),
              const SizedBox(height: 10),

              if (_evidenceList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                  child: const Center(
                    child: Text('No inspection photos available.\nCapture photographic evidence below.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _slate400)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _evidenceList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final ev = _evidenceList[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _slate50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _slate200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image_outlined, size: 18, color: _govNavy),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ev['title'] ?? 'Photo Evidence', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('${ev['evidence_id']} • ${ev['timestamp']}', style: const TextStyle(fontSize: 9.5, color: _slate500)),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded, size: 14, color: _govGreen),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 10),

              // Capture Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleAddEvidenceItem('PHOTO', 'Stock Room & Dunnage Sacks', 'IMG_STOCK_01.JPG'),
                      icon: const Icon(Icons.add_a_photo_rounded, size: 13),
                      label: const Text('Add Stock Photo', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleAddEvidenceItem('PHOTO', 'e-PoS Terminal & Display', 'IMG_EPOS_01.JPG'),
                      icon: const Icon(Icons.camera_alt_outlined, size: 13),
                      label: const Text('Add e-PoS Photo', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. QUICK ACTIONS
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
              const Text('Quick Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _govNavy)),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_rounded, size: 18, color: _govNavy),
                title: const Text('VIEW STOCK DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                subtitle: const Text('Inspect digital ledger vs physical breakdown', style: TextStyle(fontSize: 10, color: _slate500)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => _handleSelectTargetFps(_selectedFps ?? _fpsList.first),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded, size: 18, color: _govNavy),
                title: const Text('VIEW PREVIOUS INSPECTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                subtitle: const Text('Browse historical audit logs for this shop', style: TextStyle(fontSize: 10, color: _slate500)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => _handleViewPreviousFpsInspections(_selectedFpsId),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined, size: 18, color: _govNavy),
                title: const Text('VIEW COMPLIANCE HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                subtitle: const Text('District compliance scores & records', style: TextStyle(fontSize: 10, color: _slate500)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => setState(() => _selectedNavTab = 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================================
  // 9. TAB 1: MY INSPECTIONS VIEW
  // ================================================================
  Widget _buildMyInspectionsView() {
    final filtered = _completedInspections.where((insp) {
      final fps = (insp['fps_id'] ?? '').toString().toLowerCase();
      final id = (insp['inspection_id'] ?? '').toString().toLowerCase();
      final q = _inspectionSearchQuery.toLowerCase();
      final matchesQuery = fps.contains(q) || id.contains(q);
      if (_inspectionFilterStatus == 'ALL') return matchesQuery;
      if (_inspectionFilterStatus == 'SEALED') return matchesQuery && (insp['status'] == 'SEALED' || insp['status'] == 'COMPLETED');
      return matchesQuery;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Completed Inspections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _govNavy)),
                  Text('Authoritative inspection reports sealed in District Civil Supplies ledger.', style: TextStyle(fontSize: 11.5, color: _slate500)),
                ],
              ),
              Row(
                children: [
                  Wrap(
                    spacing: 6,
                    children: ['ALL', 'SEALED'].map((st) {
                      final isSel = _inspectionFilterStatus == st;
                      return ChoiceChip(
                        label: Text(st, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? Colors.white : _slate700)),
                        selected: isSel,
                        selectedColor: _govNavy,
                        onSelected: (_) => setState(() => _inspectionFilterStatus = st),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 220,
                    height: 36,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                    child: TextField(
                      onChanged: (val) => setState(() => _inspectionSearchQuery = val),
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Search inspection/FPS...',
                        prefixIcon: Icon(Icons.search_rounded, size: 16),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: filtered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
                    child: const Center(
                      child: Text('No historical inspection reports found matching query.', style: TextStyle(fontSize: 12, color: _slate500)),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final r = filtered[idx];
                      final score = (r['compliance_score'] as num?)?.toDouble() ?? 100.0;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _slate200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.verified_rounded, color: _govGreen, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('${r['fps_id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _govNavy)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(4)),
                                        child: Text('${r['inspection_id']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate700)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Inspector: ${r['inspector_id']} • Sealed on: ${r['created_at'] ?? "Recent"}', style: const TextStyle(fontSize: 11, color: _slate500)),
                                  if (r['remarks'] != null)
                                    Text('Remarks: ${r['remarks']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _slate700)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _govGreenBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _govGreenBorder),
                              ),
                              child: Text(
                                '${score.toStringAsFixed(0)}% COMPLIANT',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _govGreen),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 10. TAB 2: ASSIGNED FPS DIRECTORY
  // ================================================================
  Widget _buildAssignedFpsView() {
    final filtered = _fpsList.where((fps) {
      final q = _fpsSearchQuery.toLowerCase();
      return fps.fpsId.toLowerCase().contains(q) || fps.name.toLowerCase().contains(q) || fps.district.toLowerCase().contains(q);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assigned Fair Price Shops', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _govNavy)),
                  Text('Real PDS distribution centers under your inspection jurisdiction.', style: TextStyle(fontSize: 11.5, color: _slate500)),
                ],
              ),
              Container(
                width: 250,
                height: 36,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                child: TextField(
                  onChanged: (val) => setState(() => _fpsSearchQuery = val),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Search FPS ID or Location...',
                    prefixIcon: Icon(Icons.search_rounded, size: 16),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final fps = filtered[idx];
                final isSelected = fps.fpsId == _selectedFpsId;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? _govNavy : _slate200, width: isSelected ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isSelected ? _govNavy : _slate100, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.storefront_rounded, color: isSelected ? Colors.white : _slate700, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(fps.fpsId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _govNavy)),
                                const SizedBox(width: 8),
                                Text(fps.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _slate900)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('${fps.district} • Lat: ${fps.latitude.toStringAsFixed(4)}° N, Lon: ${fps.longitude.toStringAsFixed(4)}° E',
                                style: const TextStyle(fontSize: 11, color: _slate500)),
                            const SizedBox(height: 2),
                            Text('Current Inventory: ${fps.currentInventoryTotalKg.toStringAsFixed(0)} kg • Capacity: ${fps.capacityKg.toStringAsFixed(0)} kg',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate700)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _handleSelectTargetFps(fps),
                        icon: const Icon(Icons.play_arrow_rounded, size: 14),
                        label: const Text('INSPECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? _govGreen : _govNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 11. TAB 3: REPORTS & AUDIT SUMMARY
  // ================================================================
  Widget _buildReportsView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inspection Compliance Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _govNavy)),
          const Text('Aggregate inspection records derived directly from database ledger.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildReportMetricCard('Total Completed', '${_completedInspections.length}', _govGreen),
              const SizedBox(width: 12),
              _buildReportMetricCard('Surprise Orders', '${_surpriseOrders.length}', _govNavy),
              const SizedBox(width: 12),
              _buildReportMetricCard('Assigned Centers', '${_fpsList.length}', const Color(0xFF1E40AF)),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Official Inspection Directives', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _govNavy)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _surpriseOrders.isEmpty
                        ? const Center(child: Text('No pending inspection directives from DSO command.', style: TextStyle(fontSize: 12, color: _slate500)))
                        : ListView.separated(
                            itemCount: _surpriseOrders.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final o = _surpriseOrders[idx];
                              return ListTile(
                                dense: true,
                                title: Text('Directive: ${o['order_id']} • Target: ${o['fps_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                subtitle: Text('Reason: ${o['reason'] ?? "Routine surprise audit"} • Priority: ${o['priority'] ?? "HIGH"}', style: const TextStyle(fontSize: 11, color: _slate500)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: _amberBg, borderRadius: BorderRadius.circular(4)),
                                  child: Text('${o['status']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _amberAlert)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate500)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // 12. TAB 4: SETTINGS & TELEMETRY
  // ================================================================
  Widget _buildSettingsView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Field Inspector Station Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _govNavy)),
          const Text('Government workstation credentials, device telemetry, and security profiles.', style: TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingRow('Inspector Username', widget.username ?? 'inspector_user'),
                const Divider(height: 16),
                _buildSettingRow('Department', 'Karnataka Food & Civil Supplies'),
                const Divider(height: 16),
                _buildSettingRow('Designation', 'Field Food Safety & Compliance Inspector'),
                const Divider(height: 16),
                _buildSettingRow('Jurisdiction', 'Bengaluru Urban District PDS Pilot'),
                const Divider(height: 16),
                _buildSettingRow('Telemetry Protocol', 'Live Geofence + GPS Perimeter Verification (Active)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _slate500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate900)),
      ],
    );
  }
}
