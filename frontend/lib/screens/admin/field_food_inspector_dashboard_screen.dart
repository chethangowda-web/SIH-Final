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

  // Active Workflow Step (1 to 8)
  int _currentStep = 1;

  // Real backend dataset
  List<FpsShop> _fpsList = [];
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, DIRECTIVE, HIGH_RISK, LOW_STOCK
  String _selectedFpsId = '';
  FpsShop? _selectedFps;

  // Target Inspection Context loaded from backend DB
  Map<String, dynamic>? _targetContext;
  double _digitalRiceKg = 0.0;
  double _digitalWheatKg = 0.0;


  // Real DSO Surprise Directives & Inspection Ledger from backend
  List<Map<String, dynamic>> _surpriseOrders = [];
  String? _selectedOrderId;
  List<Map<String, dynamic>> _completedInspections = [];

  // Active Truck Dispatches for Geofence Tracking
  List<Map<String, dynamic>> _activeTrucks = [];
  Map<String, dynamic>? _associatedTruck;

  // Step 2: Geofence Verification State
  bool _geofenceVerified = false;
  double _geofenceDistanceM = 42.5;
  String _geofenceStatus = 'WAITING FOR ARRIVAL';
  String? _geofenceTimestamp;



  // Step 4: 6-Point Physical Inspection State
  final Map<int, String> _checklistResults = {
    1: 'COMPLIANT',
    2: 'COMPLIANT',
    3: 'COMPLIANT',
    4: 'COMPLIANT',
    5: 'COMPLIANT',
    6: 'COMPLIANT',
  };

  // Stock verification inputs
  final TextEditingController _observedRiceController = TextEditingController();
  final TextEditingController _observedWheatController = TextEditingController();

  // Grain Quality Testing
  double _moisturePercentage = 11.2;
  double _scaleErrorGrams = 0.0;

  // Step 5: Evidence & Inspector Observations State
  final List<Map<String, dynamic>> _evidenceList = [];
  final TextEditingController _remarksController = TextEditingController(
    text: 'All physical grain sacks weighed and inspected. Electronic weighing balance calibrated within tolerance limits. No stock diversion detected.',
  );

  // Step 6: Seizure Notice State
  bool _issueSeizureNotice = false;
  final String _seizureReason = 'Grain moisture content exceeds 12.0% FAQ statutory limit';

  // Step 8: Sealed Record Result
  Map<String, dynamic>? _sealedRecordResult;

  // Modal / Drawer mode
  bool _showMyHistoryView = false;


  // Visual Theme Colors
  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _amberAlert = Color(0xFFD97706);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
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
    _remarksController.dispose();
    super.dispose();
  }

  /// 1. Load Real Master Dataset from Backend DB APIs
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

      // 4. Load detailed target inspection context if selected
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
          _targetContext = contextData;
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
      // Graceful fallback from FPS model if direct context API fails
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
      _currentStep = 2; // Move to Travel / Geofence
    });
    await _loadTargetInspectionContext(fps.fpsId);
  }

  /// Action: Step 2 Geofence Arrival Verification via Backend API
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

  /// Action: Step 3 Confirm Target FPS Identity
  void _handleConfirmTargetFps() {
    setState(() {
      _currentStep = 4; // Advance to Physical 6-Point Inspection
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✓ Target FPS $_selectedFpsId confirmed. Physical inspection unlocked.'), backgroundColor: _govGreen),
    );
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
        'inspection_id': 'INSP-PENDING',
        'type': type,
        'title': title,
        'reference': ref,
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✓ Evidence item $evidenceId captured.'), backgroundColor: _govGreen),
    );
  }

  /// Action: Step 7 Final Inspection Report Submission to Backend DB
  Future<void> _handleSubmitInspectionReport() async {
    if (_checklistResults.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all 6 mandatory physical inspection checkpoints.'), backgroundColor: _amberAlert),
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
        remarks: '${_remarksController.text.trim()}${_issueSeizureNotice ? " [STATUTORY SEIZURE NOTICE ISSUED: $_seizureReason]" : ""}',
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
        _currentStep = 8; // Advance to Sealed Report Screen
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

  /// Action: View previous FPS inspection records from Backend DB
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
          width: 500,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _apiService.fetchFpsInspections(fpsId: fpsId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _govNavy)),
                );
              }
              final reports = (snapshot.data?['completed_inspections'] as List<dynamic>?) ?? [];
              if (reports.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No previous inspection records available for this Fair Price Shop.', style: TextStyle(fontSize: 12, color: _slate500)),
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

  Color get _scoreColor {
    final score = _computedComplianceScore;
    if (score >= 80) return _govGreen;
    if (score >= 50) return _amberAlert;
    return _dangerRed;
  }

  List<FpsShop> get _filteredFpsList {
    List<FpsShop> list = _fpsList;
    if (_selectedFilter == 'DIRECTIVE') {
      final directiveIds = _surpriseOrders.map((o) => o['fps_id'] as String?).toSet();
      list = list.where((f) => directiveIds.contains(f.fpsId)).toList();
    } else if (_selectedFilter == 'HIGH_RISK') {
      list = list.where((f) => f.status == 'HIGH_RISK').toList();
    } else if (_selectedFilter == 'LOW_STOCK') {
      list = list.where((f) => (f.currentInventoryTotalKg / (f.capacityKg == 0 ? 1 : f.capacityKg)) < 0.25).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((f) => f.fpsId.toLowerCase().contains(q) || f.name.toLowerCase().contains(q) || f.district.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  // -------------------------------------------------------------------------
  // MAIN BUILD METHOD
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final pendingOrders = _surpriseOrders.where((o) => o['status'] == 'PENDING').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildGovernmentHeader(pendingOrders),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5, color: _govNavy),
                  SizedBox(height: 14),
                  Text('Loading Master FPS Dataset & DSO Inspection Directives...', style: TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
            )
          : Column(
              children: [
                // Persistent Guided Workflow Stepper Bar
                _buildWorkflowStepper(),

                // Main Guided Workflow Content View based on current step
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildCurrentStepView(pendingOrders),
                  ),
                ),
              ],
            ),
    );
  }

  // -------------------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------------------
  PreferredSizeWidget _buildGovernmentHeader(List<Map<String, dynamic>> pendingOrders) {
    return AppBar(
      backgroundColor: _govNavy,
      foregroundColor: Colors.white,
      elevation: 2,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.shield_outlined, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Field Food Inspector Portal • Inspection & Compliance Monitoring',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
                Text(
                  'Officer: ${widget.username ?? "inspector_user"} • Zone: Bengaluru Urban • Dept: Karnataka Food & Civil Supplies • Cycle: 2026-09',
                  style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.85)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Live Connectivity Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF34D399)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_rounded, size: 12, color: Color(0xFF34D399)),
              SizedBox(width: 4),
              Text('ONLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.history_edu_rounded, size: 20),
          tooltip: 'My Inspection History',
          onPressed: () => setState(() => _showMyHistoryView = !_showMyHistoryView),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          tooltip: 'Refresh Master Dataset',
          onPressed: _loadInspectorMasterData,
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 20),
          tooltip: 'Logout Session',
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

  // -------------------------------------------------------------------------
  // PERSISTENT WORKFLOW STEPPER
  // -------------------------------------------------------------------------
  Widget _buildWorkflowStepper() {
    final steps = [
      {'num': 1, 'title': 'SELECT TARGET'},
      {'num': 2, 'title': 'TRAVEL / GEOFENCE'},
      {'num': 3, 'title': 'VERIFY FPS'},
      {'num': 4, 'title': '6-POINT INSPECTION'},
      {'num': 5, 'title': 'EVIDENCE & NOTES'},
      {'num': 6, 'title': 'REVIEW FINDINGS'},
      {'num': 7, 'title': 'SUBMIT INSPECTION'},
      {'num': 8, 'title': 'SEALED REPORT'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _slate200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: steps.map((step) {
              final stepNum = step['num'] as int;
              final title = step['title'] as String;

              final isCompleted = stepNum < _currentStep;
              final isCurrent = stepNum == _currentStep;

              Color bg = _slate100;
              Color border = _slate200;
              Color textColor = _slate500;
              Widget iconOrNum = Text('$stepNum', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor));

              if (isCompleted) {
                bg = const Color(0xFFDCFCE7);
                border = _govGreen;
                textColor = _govGreen;
                iconOrNum = const Icon(Icons.check_rounded, size: 12, color: _govGreen);
              } else if (isCurrent) {
                bg = _govNavy;
                border = _govNavy;
                textColor = Colors.white;
                iconOrNum = Text('$stepNum', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white));
              }

              return Expanded(
                child: InkWell(
                  onTap: () {
                    // Only allow navigating back to completed steps or current step
                    if (stepNum <= _currentStep || (stepNum == _currentStep + 1 && _geofenceVerified)) {
                      setState(() => _currentStep = stepNum);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: border, width: isCurrent ? 1.5 : 1.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              child: iconOrNum,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                            color: isCurrent ? Colors.white : (isCompleted ? _govGreen : _slate500),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // STEP ROUTER VIEW
  // -------------------------------------------------------------------------
  Widget _buildCurrentStepView(List<Map<String, dynamic>> pendingOrders) {
    if (_showMyHistoryView) {
      return _buildMyInspectionsHistoryView();
    }

    switch (_currentStep) {
      case 1:
        return _buildStep1SelectTarget(pendingOrders);
      case 2:
        return _buildStep2TravelGeofence();
      case 3:
        return _buildStep3VerifyFps();
      case 4:
        return _buildStep4PhysicalInspection();
      case 5:
        return _buildStep5EvidenceAndNotes();
      case 6:
        return _buildStep6ReviewFindings();
      case 7:
        return _buildStep7SubmitInspection();
      case 8:
        return _buildStep8SealedReport();
      default:
        return _buildStep1SelectTarget(pendingOrders);
    }
  }

  // =========================================================================
  // STEP 1 — SELECT TARGET FPS
  // =========================================================================
  Widget _buildStep1SelectTarget(List<Map<String, dynamic>> pendingOrders) {
    final filtered = _filteredFpsList;

    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert banner if active DSO surprise order exists
          if (pendingOrders.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _amberAlert, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DSO SURPRISE INSPECTION DIRECTIVE ACTIVE (${pendingOrders.length} RAID ORDER)',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _slate900),
                        ),
                        Text(
                          'Target: ${pendingOrders.first['fps_id']} • Reason: ${pendingOrders.first['reason'] ?? "Stock Variance"} • Priority: HIGH',
                          style: const TextStyle(fontSize: 11, color: _slate700),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final order = pendingOrders.first;
                      final targetId = order['fps_id'] as String;
                      final match = _fpsList.firstWhere((f) => f.fpsId == targetId, orElse: () => _fpsList.first);
                      _handleSelectTargetFps(match);
                    },
                    icon: const Icon(Icons.my_location_rounded, size: 14),
                    label: const Text('Execute Surprise Raid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: _amberAlert, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],

          // Search & Filter Header
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search target FPS by ID or Area (e.g. FPS-KA-BLR-001, Malleshwaram)...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 6,
                children: [
                  _buildFilterChip('All (${_fpsList.length})', 'ALL'),
                  _buildFilterChip('⚡ DSO Directives (${pendingOrders.length})', 'DIRECTIVE'),
                  _buildFilterChip('⚠️ High Risk', 'HIGH_RISK'),
                  _buildFilterChip('📦 Low Stock', 'LOW_STOCK'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'Showing ${filtered.length} Fair Price Shops assigned in District Supply Master Database:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate700),
          ),
          const SizedBox(height: 10),

          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
              child: const Center(child: Text('No inspections currently assigned matching search criteria.', style: TextStyle(fontSize: 12, color: _slate500))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length > 30 ? 30 : filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final fps = filtered[idx];
                final isSelected = fps.fpsId == _selectedFpsId;
                final hasDirective = pendingOrders.any((o) => o['fps_id'] == fps.fpsId);
                final fillRatio = (fps.currentInventoryTotalKg / (fps.capacityKg == 0 ? 1 : fps.capacityKg)).clamp(0.0, 1.0);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? _govGreen : _slate200, width: isSelected ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? _govGreen.withValues(alpha: 0.1) : _slate100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.storefront_rounded, color: isSelected ? _govGreen : _slate500, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(fps.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? _govGreen : _slate900)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(4)),
                                  child: Text(fps.fpsId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate700)),
                                ),
                                if (hasDirective) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4), border: Border.all(color: _amberAlert)),
                                    child: const Text('⚠️ DSO SURPRISE DIRECTIVE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _amberAlert)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'District: ${fps.district} • Capacity: ${fps.capacityKg.toStringAsFixed(0)} kg • Current Stock: ${fps.currentInventoryTotalKg.toStringAsFixed(0)} kg',
                              style: const TextStyle(fontSize: 11, color: _slate500),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: fillRatio,
                                minHeight: 4,
                                backgroundColor: _slate200,
                                valueColor: AlwaysStoppedAnimation(fillRatio < 0.25 ? _amberAlert : _govGreen),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _handleSelectTargetFps(fps),
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: const Text('START INSPECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _govNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => _handleViewPreviousFpsInspections(fps.fpsId),
                            child: const Text('View History', style: TextStyle(fontSize: 10.5, color: _slate500)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : _slate700)),
      selected: isSelected,
      selectedColor: _govNavy,
      backgroundColor: Colors.white,
      padding: EdgeInsets.zero,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }

  // =========================================================================
  // STEP 2 — TRAVEL & GEOFENCE ARRIVAL VERIFICATION
  // =========================================================================
  Widget _buildStep2TravelGeofence() {
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Context Bar
          _buildTargetContextSummaryHeader(),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GIS Map Column
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GIS Route Navigation & Perimeter Geofence:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                    const SizedBox(height: 8),
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _slate700),
                      ),
                      child: Stack(
                        children: [
                          // GIS Map Painter
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _MultiRouteGisMapPainter(
                                selectedTrucks: _associatedTruck != null
                                    ? [
                                        {
                                          'truck_id': _associatedTruck!['truck_id'] ?? 'KA-04-GA-9081',
                                          'target_fps_id': _selectedFpsId,
                                          'route_color': const Color(0xFF38BDF8),
                                          'route_index': 0,
                                        }
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                'GEOFENCE PERIMETER: 250m • TARGET: $_selectedFpsId (${_selectedFps?.name})',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Geofence Action Card Column
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Associated Truck/Dispatch Card if present
                    if (_associatedTruck != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
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
                                const Icon(Icons.local_shipping_rounded, color: _govNavy, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Inbound Consignment: ${_associatedTruck!["truck_id"]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Driver Name:', _associatedTruck!['driver_name']?.toString() ?? 'Ramesh Kumar'),
                            _buildSummaryRow('Origin Godown:', _associatedTruck!['origin_godown']?.toString() ?? 'FCI Central Godown'),
                            _buildSummaryRow('Status:', _associatedTruck!['status']?.toString() ?? 'EN_ROUTE', valueColor: _govGreen),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: _slate500),
                            SizedBox(width: 8),
                            Expanded(child: Text('No active inbound consignment for this shop. Proceeding with routine field inspection.', style: TextStyle(fontSize: 11, color: _slate500))),
                          ],
                        ),
                      ),
                    ],

                    // Geofence Arrival Action Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _geofenceVerified ? const Color(0xFFF0FDF4) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _geofenceVerified ? _govGreen : _slate200, width: _geofenceVerified ? 1.5 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_geofenceVerified ? Icons.gps_fixed_rounded : Icons.location_searching_rounded, color: _geofenceVerified ? _govGreen : _amberAlert, size: 22),
                              const SizedBox(width: 8),
                              const Text('Geofence Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildSummaryRow('Arrival Status:', _geofenceStatus, valueColor: _geofenceVerified ? _govGreen : _amberAlert, isBold: true),
                          _buildSummaryRow('Distance to Target:', '${_geofenceDistanceM.toStringAsFixed(1)} meters'),
                          if (_geofenceTimestamp != null) _buildSummaryRow('Verified At:', _geofenceTimestamp!),
                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isActionLoading ? null : _handleVerifyGeofenceArrival,
                              icon: _isActionLoading
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(_geofenceVerified ? Icons.check_circle_rounded : Icons.gps_fixed_rounded, size: 16),
                              label: Text(_geofenceVerified ? 'RE-VERIFY ARRIVAL' : 'VERIFY ARRIVAL AT TARGET FPS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _geofenceVerified ? _govGreen : _govNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _geofenceVerified
                                  ? () => setState(() => _currentStep = 3)
                                  : null,
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: const Text('PROCEED TO FPS VERIFICATION →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _govNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 3 — FPS VERIFICATION
  // =========================================================================
  Widget _buildStep3VerifyFps() {
    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTargetContextSummaryHeader(),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: _govNavy, size: 24),
                    SizedBox(width: 10),
                    Text('Fair Price Shop Identity & Authorization Confirmation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _slate900)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Before initiating physical checks, verify that you are physically present at the authorized location:', style: TextStyle(fontSize: 12, color: _slate500)),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                  child: Column(
                    children: [
                      _buildSummaryRow('Target FPS Code:', _selectedFpsId, isBold: true),
                      _buildSummaryRow('Fair Price Shop Name:', _selectedFps?.name ?? 'Fair Price Shop', isBold: true),
                      _buildSummaryRow('Authorized Dealer/Owner:', _targetContext?['fps']?['dealer_name']?.toString() ?? 'Karnataka Food & Civil Supplies Dealer'),
                      _buildSummaryRow('District Jurisdiction:', _selectedFps?.district ?? 'Bengaluru Urban'),
                      _buildSummaryRow('Active Allotment Cycle:', '2026-09'),
                      _buildSummaryRow('Assigned Inspector:', widget.username ?? 'inspector_user'),
                      _buildSummaryRow('Geofence Verification Status:', _geofenceVerified ? '✓ VERIFIED WITHIN GEOFENCE PERIMETER' : 'NOT VERIFIED', valueColor: _geofenceVerified ? _govGreen : _dangerRed),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleConfirmTargetFps,
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('CONFIRM TARGET FPS & START 6-POINT INSPECTION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _govGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // =========================================================================
  // STEP 4 — 6-POINT PHYSICAL INSPECTION
  // =========================================================================
  Widget _buildStep4PhysicalInspection() {
    final obsRice = double.tryParse(_observedRiceController.text.trim()) ?? _digitalRiceKg;
    final obsWheat = double.tryParse(_observedWheatController.text.trim()) ?? _digitalWheatKg;

    final diffRice = obsRice - _digitalRiceKg;
    final diffWheat = obsWheat - _digitalWheatKg;

    final moisturePass = _moisturePercentage <= 12.0;
    final scalePass = _scaleErrorGrams.abs() <= 5.0;

    return SingleChildScrollView(
      key: const ValueKey(4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTargetContextSummaryHeader(),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Statutory 6-Point Physical Verification & Quality Testing:', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: _slate900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _scoreColor),
                ),
                child: Text('Compliance Score: ${_computedComplianceScore.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _scoreColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Checkpoint 1
          _buildCheckpointCard(
            1,
            'Electronic Weighing Scale Calibration Certificate',
            'Legal Metrology Act 2009 Sec 24 • Verify valid seal stamp & electronic calibration certificate.',
          ),
          // Checkpoint 2
          _buildCheckpointCard(
            2,
            'Statutory Price & Entitlement Display Board',
            'Karnataka PDS Control Order Sec 4 • Verify opening stock & statutory commodity price display.',
          ),

          // Checkpoint 3: Physical Stock Verification against DB Digital Stock
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('3. Physical Stock vs Digital Register (Database Stock)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                    DropdownButton<String>(
                      value: _checklistResults[3],
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'COMPLIANT', child: Text('COMPLIANT', style: TextStyle(color: _govGreen, fontWeight: FontWeight.bold, fontSize: 11))),
                        DropdownMenuItem(value: 'NON_COMPLIANT', child: Text('NON-COMPLIANT', style: TextStyle(color: _dangerRed, fontWeight: FontWeight.bold, fontSize: 11))),
                        DropdownMenuItem(value: 'REQUIRES_ATTENTION', child: Text('REQUIRES ATTENTION', style: TextStyle(color: _amberAlert, fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _checklistResults[3] = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Stock table
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Commodity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500))),
                          const Expanded(child: Text('Digital Register (DB)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500))),
                          const Expanded(child: Text('Observed Physical (Inspector)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500))),
                          const Expanded(child: Text('Difference', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500))),
                        ],
                      ),
                      const Divider(height: 16),
                      // Rice
                      Row(
                        children: [
                          const Expanded(child: Text('Fortified Rice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          Expanded(child: Text('${_digitalRiceKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          Expanded(
                            child: TextField(
                              controller: _observedRiceController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${diffRice >= 0 ? "+" : ""}${diffRice.toStringAsFixed(0)} kg',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: diffRice.abs() > 50 ? _dangerRed : _govGreen),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Wheat
                      Row(
                        children: [
                          const Expanded(child: Text('Whole Wheat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          Expanded(child: Text('${_digitalWheatKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          Expanded(
                            child: TextField(
                              controller: _observedWheatController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${diffWheat >= 0 ? "+" : ""}${diffWheat.toStringAsFixed(0)} kg',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: diffWheat.abs() > 20 ? _dangerRed : _govGreen),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Checkpoint 4
          _buildCheckpointCard(
            4,
            'Beneficiary Service & Distribution Observation',
            'PDS Distribution Standards • Biometric scanner functional & no forced bundle charges.',
          ),
          // Checkpoint 5
          _buildCheckpointCard(
            5,
            'Record Maintenance & e-PoS Register Sync',
            'Karnataka PDS Directive • Daily sales register entries match server logs.',
          ),
          // Checkpoint 6
          _buildCheckpointCard(
            6,
            'Premises Cleanliness, Dunnage Crates & Hygiene Norms',
            'Warehouse Norms • Wooden dunnage crates used to prevent dampness; pest control done.',
          ),

          const SizedBox(height: 14),

          // Quality Testing Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Integrated Grain Quality & Weighing Calibration Testing:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                const SizedBox(height: 12),

                // Moisture
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grain Moisture: ${_moisturePercentage.toStringAsFixed(1)}% (Limit: 12.0%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: moisturePass ? _govGreen : _dangerRed)),
                          Slider(
                            value: _moisturePercentage,
                            min: 8.0,
                            max: 18.0,
                            divisions: 100,
                            activeColor: moisturePass ? _govGreen : _dangerRed,
                            onChanged: (val) => setState(() => _moisturePercentage = val),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: moisturePass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                      child: Text(moisturePass ? 'PASS' : 'FAIL (>12%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: moisturePass ? _govGreen : _dangerRed)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Scale Error
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scale Calibration Error: ${_scaleErrorGrams.toStringAsFixed(1)} grams (Limit: ±5.0g)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scalePass ? _govGreen : _dangerRed)),
                          Slider(
                            value: _scaleErrorGrams,
                            min: -50.0,
                            max: 50.0,
                            divisions: 100,
                            activeColor: scalePass ? _govGreen : _dangerRed,
                            onChanged: (val) => setState(() => _scaleErrorGrams = val),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: scalePass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                      child: Text(scalePass ? 'TOLERANCE OK' : 'FAIL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: scalePass ? _govGreen : _dangerRed)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _currentStep = 5),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('PROCEED TO EVIDENCE & INSPECTOR OBSERVATIONS →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _govNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointCard(int num, String title, String subtitle) {
    final result = _checklistResults[num] ?? 'COMPLIANT';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
      child: Row(
        children: [
          Text('$num.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _govNavy)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _slate900)),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: _slate500)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: result,
            isDense: true,
            items: const [
              DropdownMenuItem(value: 'COMPLIANT', child: Text('COMPLIANT', style: TextStyle(color: _govGreen, fontWeight: FontWeight.bold, fontSize: 11))),
              DropdownMenuItem(value: 'NON_COMPLIANT', child: Text('NON-COMPLIANT', style: TextStyle(color: _dangerRed, fontWeight: FontWeight.bold, fontSize: 11))),
              DropdownMenuItem(value: 'REQUIRES_ATTENTION', child: Text('REQUIRES ATTENTION', style: TextStyle(color: _amberAlert, fontWeight: FontWeight.bold, fontSize: 11))),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _checklistResults[num] = val);
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 5 — EVIDENCE & INSPECTOR OBSERVATIONS
  // =========================================================================
  Widget _buildStep5EvidenceAndNotes() {
    return SingleChildScrollView(
      key: const ValueKey(5),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTargetContextSummaryHeader(),
          const SizedBox(height: 14),

          // Captured Evidence Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Captured Photo & Inspection Document Evidence:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                    Wrap(
                      spacing: 6,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _handleAddEvidenceItem('PHOTO', 'Weighing Balance Stamp Photo', 'IMG-2026-STAMP.jpg'),
                          icon: const Icon(Icons.camera_alt_rounded, size: 14),
                          label: const Text('Add Stamp Photo', style: TextStyle(fontSize: 10.5)),
                          style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _handleAddEvidenceItem('DOCUMENT', 'Physical Register Log Copy', 'DOC-2026-REGISTER.pdf'),
                          icon: const Icon(Icons.attach_file_rounded, size: 14),
                          label: const Text('Add Register Doc', style: TextStyle(fontSize: 10.5)),
                          style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_evidenceList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(6)),
                    child: const Center(child: Text('No evidence uploaded yet. Click buttons above to capture physical inspection proof.', style: TextStyle(fontSize: 11.5, color: _slate500))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _evidenceList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = _evidenceList[idx];
                      return ListTile(
                        dense: true,
                        leading: Icon(item['type'] == 'PHOTO' ? Icons.image_rounded : Icons.description_rounded, color: _govNavy, size: 20),
                        title: Text('${item['evidence_id']} • ${item['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: Text('Inspector: ${item['inspector']} • Timestamp: ${item['timestamp']} • Ref: ${item['reference']}', style: const TextStyle(fontSize: 10.5, color: _slate500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: _dangerRed),
                          onPressed: () => setState(() => _evidenceList.removeAt(idx)),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Structured Inspector Notes
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Official Inspector Observations & Field Notes:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                    Text('${_remarksController.text.length} Chars • Saved', style: const TextStyle(fontSize: 11, color: _govGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _remarksController,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _slate50,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _currentStep = 6),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('PROCEED TO REVIEW INSPECTION FINDINGS →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _govNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 6 — REVIEW FINDINGS
  // =========================================================================
  Widget _buildStep6ReviewFindings() {
    int compliantCount = 0;
    int nonCompliantCount = 0;
    _checklistResults.forEach((_, v) {
      if (v == 'COMPLIANT') compliantCount++;
      if (v == 'NON_COMPLIANT') nonCompliantCount++;
    });

    final obsRice = double.tryParse(_observedRiceController.text.trim()) ?? _digitalRiceKg;
    final obsWheat = double.tryParse(_observedWheatController.text.trim()) ?? _digitalWheatKg;

    return SingleChildScrollView(
      key: const ValueKey(6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTargetContextSummaryHeader(),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.fact_check_rounded, color: _govNavy, size: 22),
                    SizedBox(width: 8),
                    Text('Inspection Summary & Statutory Findings Review', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _slate900)),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                  child: Column(
                    children: [
                      _buildSummaryRow('Target Fair Price Shop:', '$_selectedFpsId (${_selectedFps?.name})', isBold: true),
                      _buildSummaryRow('Geofence Verification:', _geofenceVerified ? '✓ Verified (${_geofenceDistanceM.toStringAsFixed(1)}m)' : 'Pending', valueColor: _geofenceVerified ? _govGreen : _dangerRed),
                      _buildSummaryRow('Statutory 6-Point Checklist:', '$compliantCount of 6 COMPLIANT ($nonCompliantCount Non-Compliant)', isBold: true, valueColor: _scoreColor),
                      _buildSummaryRow('Physical Rice Stock Checked:', '${obsRice.toStringAsFixed(0)} kg (Digital DB: ${_digitalRiceKg.toStringAsFixed(0)} kg)'),
                      _buildSummaryRow('Physical Wheat Stock Checked:', '${obsWheat.toStringAsFixed(0)} kg (Digital DB: ${_digitalWheatKg.toStringAsFixed(0)} kg)'),
                      _buildSummaryRow('Grain Moisture Content Test:', '${_moisturePercentage.toStringAsFixed(1)}% (${_moisturePercentage <= 12.0 ? "PASS" : "FAIL"})', valueColor: _moisturePercentage <= 12.0 ? _govGreen : _dangerRed),
                      _buildSummaryRow('Weighing Scale Error Test:', '${_scaleErrorGrams.toStringAsFixed(1)}g (${_scaleErrorGrams.abs() <= 5.0 ? "PASS" : "FAIL"})'),
                      _buildSummaryRow('Captured Evidence Attachments:', '${_evidenceList.length} Items'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Seizure Directive Checkbox
                Container(
                  decoration: BoxDecoration(
                    color: _issueSeizureNotice ? const Color(0xFFFEF2F2) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _issueSeizureNotice ? _dangerRed : _slate200),
                  ),
                  child: SwitchListTile(
                    value: _issueSeizureNotice,
                    onChanged: (val) => setState(() => _issueSeizureNotice = val),
                    activeColor: _dangerRed,
                    title: const Text('Issue Statutory Seizure Notice (Sec 6A ECA 1955)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _dangerRed)),
                    subtitle: const Text('Freezes grain allotment & locks shop e-PoS transaction rights.', style: TextStyle(fontSize: 11, color: _slate500)),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _currentStep = 4),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Edit Inspection Checks'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _currentStep = 7),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('PROCEED TO SUBMIT →', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
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
  }

  // =========================================================================
  // STEP 7 — SUBMIT INSPECTION
  // =========================================================================
  Widget _buildStep7SubmitInspection() {
    return SingleChildScrollView(
      key: const ValueKey(7),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTargetContextSummaryHeader(),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: _govNavy, size: 24),
                    SizedBox(width: 10),
                    Text('Final Official Submission & Cryptographic Ledger Sealing', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _slate900)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'You are about to submit and lock this statutory physical inspection certificate into the Karnataka PDS Compliance Ledger. Once sealed, this record becomes immutable.',
                  style: TextStyle(fontSize: 12, color: _slate500),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: Column(
                    children: [
                      _buildSummaryRow('Target FPS ID:', _selectedFpsId, isBold: true),
                      _buildSummaryRow('Inspector ID:', widget.username ?? 'inspector_user', isBold: true),
                      _buildSummaryRow('Compliance Score:', '${_computedComplianceScore.toStringAsFixed(0)}%', isBold: true, valueColor: _scoreColor),
                      _buildSummaryRow('Checklist Verification:', '6 / 6 Points Completed'),
                      _buildSummaryRow('Evidence Attachments:', '${_evidenceList.length} Items Captured'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleSubmitInspectionReport,
                    icon: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock_rounded, size: 20),
                    label: Text(_isSubmitting ? 'Sealing Report on Ledger...' : 'SUBMIT & SEAL INSPECTION CERTIFICATE', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _govGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // =========================================================================
  // STEP 8 — SEALED RECORD / REPORT
  // =========================================================================
  Widget _buildStep8SealedReport() {
    final res = _sealedRecordResult ?? {};
    final inspId = res['inspection_id'] ?? 'INSP-SEALED-2026';
    final hash = res['sealed_hash'] ?? '0X8F9A7B3C1E2D4F5A6B7C8D9E0F1A2B3C';
    final sealedAt = res['sealed_at'] ?? DateTime.now().toString().split('.')[0];

    return SingleChildScrollView(
      key: const ValueKey(8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF86EFAC))),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: _govGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✓ OFFICIAL INSPECTION REPORT SEALED', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govGreen)),
                      Text('Inspection certificate #$inspId has been permanently registered in the Karnataka Compliance Ledger.', style: const TextStyle(fontSize: 11.5, color: _slate700)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Certificate document view
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _slate200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Text('GOVERNMENT OF KARNATAKA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govNavy, letterSpacing: 0.8)),
                      const Text('Department of Food, Civil Supplies & Consumer Affairs', style: TextStyle(fontSize: 11, color: _slate500)),
                      const SizedBox(height: 4),
                      const Text('STATUTORY FIELD INSPECTION CERTIFICATE', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _slate900)),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                _buildSummaryRow('Certificate ID:', inspId, isBold: true),
                _buildSummaryRow('Target Fair Price Shop:', '$_selectedFpsId (${_selectedFps?.name})', isBold: true),
                _buildSummaryRow('Inspecting Officer:', widget.username ?? 'inspector_user'),
                _buildSummaryRow('Sealing Timestamp:', sealedAt),
                _buildSummaryRow('Compliance Score:', '${_computedComplianceScore.toStringAsFixed(0)}%', isBold: true, valueColor: _scoreColor),
                _buildSummaryRow('Digital Seal Hash:', hash, isBold: true, valueColor: _govNavy),
                const Divider(height: 20),

                const Text('Physical Audit Checkpoint Findings:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate700)),
                const SizedBox(height: 8),
                ..._checklistResults.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(e.value == 'COMPLIANT' ? Icons.check_circle_rounded : Icons.warning_rounded, size: 14, color: e.value == 'COMPLIANT' ? _govGreen : _amberAlert),
                          const SizedBox(width: 6),
                          Text('Checkpoint ${e.key}: ${e.value}', style: const TextStyle(fontSize: 11.5)),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentStep = 1;
                          _sealedRecordResult = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Start New Inspection'),
                      style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showMyHistoryView = true),
                      icon: const Icon(Icons.history_edu_rounded, size: 16),
                      label: const Text('View All My Inspections'),
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

  // =========================================================================
  // MY INSPECTIONS HISTORY VIEW
  // =========================================================================
  Widget _buildMyInspectionsHistoryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Inspector Personal Inspection History Ledger:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _slate900)),
              TextButton.icon(
                onPressed: () => setState(() => _showMyHistoryView = false),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Close History View'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
            child: _completedInspections.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No historical inspections submitted yet.', style: TextStyle(fontSize: 12, color: _slate500))))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _completedInspections.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = _completedInspections[idx];
                      final score = (item['compliance_score'] as num?)?.toDouble() ?? 100.0;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.verified_rounded, color: _govGreen, size: 22),
                        title: Text('Inspection ID: ${item['inspection_id']} • Target: ${item['fps_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        subtitle: Text('Inspector: ${item['inspector_id']} • Timestamp: ${item['created_at'] ?? "Recent"}', style: const TextStyle(fontSize: 11, color: _slate500)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                          child: Text('${score.toStringAsFixed(0)}% SEALED', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _govGreen)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // HELPER WIDGETS
  // -------------------------------------------------------------------------
  Widget _buildTargetContextSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: _govNavy, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENT TARGET: ${_selectedFps?.name ?? _selectedFpsId} ($_selectedFpsId)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _slate900)),
                Text('District: ${_selectedFps?.district ?? "Bengaluru Urban"} • Digital Stock: ${_digitalRiceKg.toStringAsFixed(0)} kg Rice / ${_digitalWheatKg.toStringAsFixed(0)} kg Wheat', style: const TextStyle(fontSize: 11, color: _slate500)),
              ],
            ),
          ),
          if (_selectedOrderId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4), border: Border.all(color: _amberAlert)),
              child: const Text('⚠️ DSO SURPRISE ORDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _amberAlert)),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String val, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: _slate500)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              val,
              style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? _slate900),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom GIS Map Painter rendering route curves and truck positions
class _MultiRouteGisMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> selectedTrucks;

  _MultiRouteGisMapPainter({required this.selectedTrucks});

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 35) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    for (double y = 0; y < size.height; y += 35) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final origin = Offset(60, size.height - 50);
    final dest = Offset(size.width * 0.7, 60);
    final cp = Offset(size.width * 0.35, size.height * 0.30);

    final routePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(origin.dx, origin.dy);
    path.quadraticBezierTo(cp.dx, cp.dy, dest.dx, dest.dy);
    canvas.drawPath(path, routePaint);

    // Target pin
    canvas.drawCircle(dest, 6, Paint()..color = const Color(0xFF38BDF8));
  }

  @override
  bool shouldRepaint(covariant _MultiRouteGisMapPainter oldDelegate) {
    return oldDelegate.selectedTrucks != selectedTrucks;
  }
}
