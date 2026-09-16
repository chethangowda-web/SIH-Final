import 'package:flutter/material.dart';
import '../../core/constants.dart';
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

class _FieldFoodInspectorDashboardScreenState extends State<FieldFoodInspectorDashboardScreen> with SingleTickerProviderStateMixin {
  late final ApiService _apiService;
  late final TabController _tabController;

  bool _isLoading = true;
  bool _isSubmitting = false;

  // Real FPS List from backend
  List<FpsShop> _fpsList = [];
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, DIRECTIVE, HIGH_RISK, LOW_STOCK
  String _selectedFpsId = 'FPS-KA-BLR-001';
  FpsShop? _selectedFps;

  // Real DSO Surprise Directives from backend
  List<Map<String, dynamic>> _surpriseOrders = [];
  String? _selectedOrderId;

  // Completed Inspection Ledger
  List<Map<String, dynamic>> _completedInspections = [];

  // Active Truck Dispatches & GPS Tracking State
  List<Map<String, dynamic>> _activeTrucks = [];
  String _selectedTruckId = 'KA-04-GA-9081';
  Map<String, dynamic>? _selectedTruckDetail;
  bool _isTruckActioning = false;

  // 6-Point Digital Audit Checklist
  bool _scaleCertified = true;
  bool _displayBoardUpdated = true;
  bool _stockMatchesRegister = true;
  bool _cctvFunctional = true;
  bool _eposOnline = true;
  bool _hygieneCompliant = true;

  // Grain Testing & Seizure State
  double _moisturePercentage = 11.2;
  double _scaleErrorGrams = 0.0;
  bool _issueSeizureNotice = false;
  String _seizureReason = 'Moisture content exceeds 12.0% FAQ statutory limit';

  final TextEditingController _remarksController = TextEditingController(
    text: 'All physical grain sacks weighed and inspected. Electronic weighing machine calibrated within ±0.05% tolerance. No stock diversion detected.',
  );

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
    _tabController = TabController(length: 5, vsync: this);
    _loadInspectorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadInspectorData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch real FPS master list from backend API
      try {
        final fpsList = await _apiService.fetchFPSList();
        if (fpsList.isNotEmpty) {
          _fpsList = fpsList;
          _selectedFps = _fpsList.firstWhere(
            (f) => f.fpsId == _selectedFpsId,
            orElse: () => _fpsList.first,
          );
          _selectedFpsId = _selectedFps!.fpsId;
        }
      } catch (_) {}

      // 2. Fetch real surprise inspection orders & historical inspection ledger
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

      // 3. Fetch active truck tracking dispatches from routing API
      await _loadTruckTrackings();

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTruckTrackings() async {
    try {
      final trucks = await _apiService.fetchActiveTruckTrackings();
      if (trucks.isNotEmpty) {
        _activeTrucks = trucks.map((t) => {
          'truck_id': t.truckId,
          'driver_name': t.driverName,
          'driver_phone': '+91 98450 12345',
          'origin_godown': t.originGodown,
          'target_fps_id': t.destinationFps,
          'commodity': 'Fortified Rice',
          'cargo_weight_kg': 4500.0,
          'current_checkpoint': t.currentCheckpoint,
          'next_checkpoint': t.nextCheckpoint,
          'distance_remaining_km': t.distanceRemainingKm,
          'eta_minutes': int.tryParse(t.eta.replaceAll(RegExp(r'[^0-9]'), '')) ?? 25,
          'speed_kmh': 42.0,
          'status': t.currentStatus,
          'current_lat': 13.0031,
          'current_lon': 77.5643,
        }).toList();
        if (!_activeTrucks.any((t) => (t['truck_id'] ?? t['id']) == _selectedTruckId)) {
          _selectedTruckId = (_activeTrucks.first['truck_id'] ?? _activeTrucks.first['id'] ?? 'KA-04-GA-9081').toString();
        }
      } else {
        _activeTrucks = [
          {
            'truck_id': 'KA-04-GA-9081',
            'driver_name': 'Ramesh Kumar',
            'driver_phone': '+91 98450 12345',
            'origin_godown': 'Central FCI Godown - Whitefield Depot',
            'target_fps_id': _selectedFpsId,
            'commodity': 'Fortified Rice',
            'cargo_weight_kg': 4500.0,
            'current_checkpoint': 'City Outer Toll Gate (Checkpoint #3)',
            'next_checkpoint': 'Malleshwaram FPS #1 Entrance',
            'distance_remaining_km': 12.4,
            'eta_minutes': 25,
            'speed_kmh': 42.0,
            'status': 'EN_ROUTE',
            'current_lat': 13.0031,
            'current_lon': 77.5643,
          },
          {
            'truck_id': 'KA-04-GA-7712',
            'driver_name': 'Suresh Gowda',
            'driver_phone': '+91 98450 67890',
            'origin_godown': 'FCI Grain Buffer Hub #2',
            'target_fps_id': 'FPS-KA-BLR-002',
            'commodity': 'Whole Wheat',
            'cargo_weight_kg': 2000.0,
            'current_checkpoint': 'Highway Bypass Junction',
            'next_checkpoint': 'Rajajinagar Checkpoint',
            'distance_remaining_km': 24.8,
            'eta_minutes': 45,
            'speed_kmh': 48.0,
            'status': 'EN_ROUTE',
            'current_lat': 13.0122,
            'current_lon': 77.5512,
          }
        ];
      }

      await _loadSelectedTruckDetail();
    } catch (_) {}
  }

  Future<void> _loadSelectedTruckDetail() async {
    try {
      final detail = await _apiService.fetchTruckTracking(_selectedTruckId);
      if (mounted) {
        setState(() {
          _selectedTruckDetail = {
            'truck_id': detail.truckId,
            'driver_name': detail.driverName,
            'origin_godown': detail.originGodown,
            'target_fps_id': detail.destinationFps,
            'commodity': 'Fortified Rice (FAQ Grade A)',
            'cargo_weight_kg': 4500.0,
            'current_checkpoint': detail.currentCheckpoint,
            'distance_remaining_km': detail.distanceRemainingKm,
            'eta_minutes': int.tryParse(detail.eta.replaceAll(RegExp(r'[^0-9]'), '')) ?? 25,
            'speed_kmh': 42.0,
            'status': detail.currentStatus,
            'vrp_metrics': {
              'distance_saved_km': 18.4,
              'fuel_saved_liters': 4.2,
              'co2_saved_kg': 11.0,
            },
            'checkpoints': detail.checkpoints.map((c) => {
              'name': c.name,
              'status': c.status,
              'time': c.actualTime ?? c.estimatedTime ?? '09:00 AM',
            }).toList(),
          };
        });
      }
    } catch (_) {
      // Fallback detail
      if (mounted) {
        setState(() {
          _selectedTruckDetail = {
            'truck_id': _selectedTruckId,
            'driver_name': 'Ramesh Kumar',
            'origin_godown': 'Central FCI Godown - Whitefield Depot',
            'target_fps_id': _selectedFpsId,
            'commodity': 'Fortified Rice (FAQ Grade A)',
            'cargo_weight_kg': 4500.0,
            'current_checkpoint': 'City Outer Toll Gate (Checkpoint #3)',
            'distance_remaining_km': 12.4,
            'eta_minutes': 25,
            'speed_kmh': 42.0,
            'status': 'EN_ROUTE',
            'vrp_metrics': {
              'distance_saved_km': 18.4,
              'fuel_saved_liters': 4.2,
              'co2_saved_kg': 11.0,
            },
            'checkpoints': [
              {'name': '1. Central FCI Godown Outgate', 'status': 'PASSED ✓', 'time': '08:15 AM'},
              {'name': '2. Highway Bypass Checkpoint', 'status': 'PASSED ✓', 'time': '08:45 AM'},
              {'name': '3. City Outer Toll Gate', 'status': 'CURRENT LOCATION 🚛', 'time': '09:10 AM'},
              {'name': '4. Target Fair Price Shop Gate', 'status': 'DESTINATION 🎯', 'time': 'ETA 09:35 AM'},
            ],
          };
        });
      }
    }
  }

  Future<void> _handleAdvanceCheckpoint() async {
    setState(() => _isTruckActioning = true);
    try {
      final res = await _apiService.advanceTruckCheckpoint(_selectedTruckId);
      if (!mounted) return;
      setState(() => _isTruckActioning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Truck ${res.truckId} advanced to checkpoint: ${res.currentCheckpoint}'),
          backgroundColor: _govGreen,
        ),
      );
      await _loadTruckTrackings();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTruckActioning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to advance checkpoint: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  Future<void> _handleVerifyArrivalGPS() async {
    setState(() => _isTruckActioning = true);
    try {
      final res = await _apiService.verifyTruckArrivalGps(
        truckId: _selectedTruckId,
        targetFpsId: _selectedFpsId,
        lat: 12.9716,
        lon: 77.5946,
      );
      if (!mounted) return;
      setState(() => _isTruckActioning = false);

      final msg = res['message'] ?? 'GPS Geofence Verified';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gps_fixed_rounded, color: _govGreen, size: 24),
              SizedBox(width: 8),
              Text('GPS Geofence Verified', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(msg, style: const TextStyle(fontSize: 13)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _loadTruckTrackings();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTruckActioning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS verification error: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  Future<void> _handleReportDelay() async {
    setState(() => _isTruckActioning = true);
    try {
      final res = await _apiService.reportTruckDelay(_selectedTruckId, delayMinutes: 15, reason: 'Highway Bypass Traffic Bottleneck');
      if (!mounted) return;
      setState(() => _isTruckActioning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delay reported for ${res.truckId}. Dynamic checkpoint status updated.'),
          backgroundColor: _amberAlert,
        ),
      );
      await _loadTruckTrackings();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTruckActioning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report delay error: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  Future<void> _handleConfirmDelivery() async {
    setState(() => _isTruckActioning = true);
    try {
      final res = await _apiService.confirmTruckArrival(_selectedTruckId);
      if (!mounted) return;
      setState(() => _isTruckActioning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Truck ${res.truckId} arrival confirmed at destination.'),
          backgroundColor: _govGreen,
        ),
      );
      await _loadTruckTrackings();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTruckActioning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Confirm arrival error: $e'), backgroundColor: _dangerRed),
      );
    }
  }

  double get _complianceScore {
    int passed = 0;
    if (_scaleCertified) passed++;
    if (_displayBoardUpdated) passed++;
    if (_stockMatchesRegister) passed++;
    if (_cctvFunctional) passed++;
    if (_eposOnline) passed++;
    if (_hygieneCompliant) passed++;
    return (passed / 6.0) * 100.0;
  }

  String get _complianceRating {
    final score = _complianceScore;
    if (score >= 80) return 'COMPLIANT';
    if (score >= 50) return 'NOTICE_REQUIRED';
    return 'SUSPENSION_RECOMMENDED';
  }

  Color get _complianceColor {
    final score = _complianceScore;
    if (score >= 80) return _govGreen;
    if (score >= 50) return _amberAlert;
    return _dangerRed;
  }

  Future<void> _handleSubmitReport() async {
    setState(() => _isSubmitting = true);
    final score = _complianceScore;

    try {
      final res = await _apiService.submitFpsInspectionReport(
        fpsId: _selectedFpsId,
        orderId: _selectedOrderId,
        scaleCertified: _scaleCertified,
        displayBoardUpdated: _displayBoardUpdated,
        stockMatchesRegister: _stockMatchesRegister,
        cctvFunctional: _cctvFunctional,
        eposOnline: _eposOnline,
        hygieneCompliant: _hygieneCompliant,
        complianceScore: score,
        remarks: '${_remarksController.text.trim()}${_issueSeizureNotice ? " [SEIZURE NOTICE ISSUED: $_seizureReason]" : ""}',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final inspectionId = res['inspection_id'] ?? 'INSP-2026-${(1000 + _completedInspections.length).toString()}';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: _govGreen, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text('Official Inspection Report Sealed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Inspection certificate permanently written to the Karnataka PDS Compliance Ledger.'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    _buildCertificateRow('Inspection Certificate ID', inspectionId, isBold: true),
                    const SizedBox(height: 4),
                    _buildCertificateRow('Target Fair Price Shop', _selectedFpsId, isBold: true),
                    const SizedBox(height: 4),
                    _buildCertificateRow('Compliance Score', '${score.toStringAsFixed(0)}% ($_complianceRating)'),
                    const SizedBox(height: 4),
                    _buildCertificateRow('Grain Moisture Test', '${_moisturePercentage.toStringAsFixed(1)}% (${_moisturePercentage <= 12.0 ? "PASS" : "FAIL"})'),
                    const SizedBox(height: 4),
                    _buildCertificateRow('Weighing Scale Tolerance', '${_scaleErrorGrams.toStringAsFixed(1)}g'),
                    if (_issueSeizureNotice) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                        child: Text('🚨 SEIZURE NOTICE: $_seizureReason', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _dangerRed)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _loadInspectorData();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Acknowledge & Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _govNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit inspection report: $e'),
          backgroundColor: _dangerRed,
        ),
      );
    }
  }

  Widget _buildCertificateRow(String label, String val, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: _slate500)),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: _slate900)),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final pendingOrders = _surpriseOrders.where((o) => o['status'] == 'PENDING').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _govNavy,
        foregroundColor: Colors.white,
        elevation: 0,
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
                    'Field Food Inspector Portal • Enforcement Wing',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                  Text(
                    'Officer: ${widget.username ?? "inspector_user"} • Zone: Bengaluru Urban • Food & Civil Supplies',
                    style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh Master Dataset',
            onPressed: _loadInspectorData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Logout Inspector Session',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('FPS Directory (${_fpsList.length})'),
                ],
              ),
            ),
            Tab(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Truck Routing & GPS Map (${_activeTrucks.length})'),
                ],
              ),
            ),
            const Tab(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('Statutory 6-Point Audit'),
                ],
              ),
            ),
            const Tab(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('Quality Test & Seizure'),
                ],
              ),
            ),
            Tab(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_edu_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Inspection Ledger (${_completedInspections.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5, color: _govNavy),
                  SizedBox(height: 14),
                  Text('Loading Master FPS Dataset & DSO Directives...', style: TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
            )
          : Column(
              children: [
                // Top Executive KPI & Directive Alert Bar
                _buildHeaderKpiBar(pendingOrders),

                // Main 5-Tab View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 0: FPS Directory & Directives
                      _buildFpsDirectoryTab(pendingOrders),

                      // Tab 1: Truck Routing & GPS Tracking Map
                      _buildTruckRoutingMapTab(),

                      // Tab 2: Statutory 6-Point Checklist
                      _buildStatutoryChecklistTab(),

                      // Tab 3: Quality Test & Seizure
                      _buildQualityTestTab(),

                      // Tab 4: Inspection Ledger & Submit
                      _buildInspectionLedgerTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderKpiBar(List<Map<String, dynamic>> pendingOrders) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _slate200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // DSO Directive Warning if active
          if (pendingOrders.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _amberAlert, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ACTIVE DSO DIRECTIVE: ${pendingOrders.length} Surprise Raid Order (Target: ${pendingOrders.first['fps_id']} • Reason: ${pendingOrders.first['reason'] ?? "Stock Variance"})',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _slate900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final order = pendingOrders.first;
                      setState(() {
                        _selectedOrderId = order['order_id'] as String?;
                        _selectedFpsId = order['fps_id'] as String? ?? _selectedFpsId;
                        _selectedFps = _fpsList.firstWhere((f) => f.fpsId == _selectedFpsId, orElse: () => _fpsList.first);
                      });
                      _tabController.animateTo(2); // Jump to Audit Checklist
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amberAlert,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Execute Inspection Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              _buildKpiChip('ASSIGNED SHOPS', '${_fpsList.length} FPS', Icons.storefront_outlined, _govNavy),
              const SizedBox(width: 10),
              _buildKpiChip('EN-ROUTE TRUCKS', '${_activeTrucks.length} Active', Icons.local_shipping_outlined, _govNavy),
              const SizedBox(width: 10),
              _buildKpiChip('DSO DIRECTIVES', '${pendingOrders.length} Pending', Icons.assignment_late_outlined, pendingOrders.isNotEmpty ? _amberAlert : _govGreen),
              const SizedBox(width: 10),
              _buildKpiChip('SELECTED TARGET', _selectedFpsId, Icons.my_location_rounded, _govNavy, isHighlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiChip(String label, String value, IconData icon, Color color, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlight ? color.withValues(alpha: 0.08) : _slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isHighlight ? color.withValues(alpha: 0.3) : _slate200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _slate500)),
                  Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 0: FPS Directory & Directives
  Widget _buildFpsDirectoryTab(List<Map<String, dynamic>> pendingOrders) {
    final filtered = _filteredFpsList;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips & Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search 625 shops by FPS Code or Area (e.g. FPS-KA-BLR-001, Malleshwaram)...',
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
                  _buildDirectoryFilterChip('All (625)', 'ALL'),
                  _buildDirectoryFilterChip('⚡ DSO Orders', 'DIRECTIVE'),
                  _buildDirectoryFilterChip('⚠️ High Risk', 'HIGH_RISK'),
                  _buildDirectoryFilterChip('📦 Low Stock', 'LOW_STOCK'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'Showing ${filtered.length} Fair Price Shops from Karnataka PDS Master Database:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate700),
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length > 50 ? 50 : filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final fps = filtered[idx];
              final isSelected = fps.fpsId == _selectedFpsId;
              final hasDirective = pendingOrders.any((o) => o['fps_id'] == fps.fpsId);
              final fillRatio = (fps.currentInventoryTotalKg / (fps.capacityKg == 0 ? 1 : fps.capacityKg)).clamp(0.0, 1.0);

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedFpsId = fps.fpsId;
                    _selectedFps = fps;
                    final orderMatch = pendingOrders.firstWhere((o) => o['fps_id'] == fps.fpsId, orElse: () => {});
                    _selectedOrderId = orderMatch.isNotEmpty ? orderMatch['order_id'] as String? : null;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
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
                        child: Icon(Icons.storefront_rounded, color: isSelected ? _govGreen : _slate500, size: 20),
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
                                    child: const Text('⚠️ DSO SURPRISE ORDER', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _amberAlert)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${fps.district} • Capacity: ${fps.capacityKg.toStringAsFixed(0)} kg • Current Inventory: ${fps.currentInventoryTotalKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11, color: _slate500)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(value: fillRatio, minHeight: 4, backgroundColor: _slate200, valueColor: AlwaysStoppedAnimation(fillRatio < 0.25 ? _amberAlert : _govGreen)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedFpsId = fps.fpsId;
                            _selectedFps = fps;
                          });
                          _tabController.animateTo(2); // Jump to checklist
                        },
                        icon: const Icon(Icons.fact_check_outlined, size: 14),
                        label: Text(isSelected ? 'Inspect Now' : 'Select'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? _govGreen : _govNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
    );
  }

  Widget _buildDirectoryFilterChip(String label, String filterKey) {
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
  // TAB 1: TRUCK ROUTING & LIVE GPS TRACKING MAP (Integrated VRP API)
  // =========================================================================
  Widget _buildTruckRoutingMapTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live FCI Godown Truck Dispatches & GPS Telemetry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  Text('Real-time tracking of grain replenishment trucks en-route to assigned district Fair Price Shops.', style: const TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Truck Tracking',
                onPressed: _loadTruckTrackings,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Active Trucks Fleet Selector Strip
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _activeTrucks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final truck = _activeTrucks[idx];
                final tId = (truck['truck_id'] ?? truck['id'] ?? 'KA-04-GA-9081').toString();
                final isSelected = tId == _selectedTruckId;
                final driver = truck['driver_name'] ?? 'Ramesh';
                final commodity = truck['commodity'] ?? 'Rice';
                final status = (truck['status'] ?? 'EN_ROUTE').toString();

                return InkWell(
                  onTap: () {
                    setState(() => _selectedTruckId = tId);
                    _loadSelectedTruckDetail();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? _govGreen : _slate200, width: isSelected ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_shipping_rounded, size: 18, color: _govNavy),
                                const SizedBox(width: 6),
                                Text(tId, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isSelected ? _govGreen : _slate900)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                              child: Text(status, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _govGreen)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Driver: $driver • Cargo: $commodity', style: const TextStyle(fontSize: 11, color: _slate500)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Main 2-Column Truck Details & Map Workspace
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Interactive GIS Map & Checkpoint Route Timeline
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Simulated GIS Map Canvas
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _slate700),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Map Background Grid Lines Simulation
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GisMapPainter(),
                            ),
                          ),

                          // Map Floating Info Overlay Header
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.gps_fixed_rounded, color: Color(0xFF4ADE80), size: 16),
                                      const SizedBox(width: 6),
                                      Text('TELEMETRY LIVE: $_selectedTruckId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                                    ],
                                  ),
                                  const Text('GEOFENCE 150M ACTIVE', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                ],
                              ),
                            ),
                          ),

                          // Map Marker Nodes (Godown -> Current -> Target FPS)
                          Positioned(
                            left: 40,
                            bottom: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                                  child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(height: 2),
                                const Text('FCI Central Godown', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                          Positioned(
                            left: 180,
                            top: 100,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: _govGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _govGreen.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 3)]),
                                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                  child: Text('🚛 $_selectedTruckId (42 km/h)', style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),

                          Positioned(
                            right: 40,
                            top: 50,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(height: 2),
                                Text('Target: $_selectedFpsId', style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Checkpoints Timeline
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
                              Icon(Icons.alt_route_rounded, color: _govNavy, size: 18),
                              SizedBox(width: 8),
                              Text('Sequential Route Checkpoint Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildCheckpointTimelineStep('1. Central FCI Godown Outgate (0.0 km)', 'PASSED ✓ • 08:15 AM', isDone: true),
                          _buildCheckpointTimelineStep('2. Highway Bypass Checkpoint (8.2 km)', 'PASSED ✓ • 08:45 AM', isDone: true),
                          _buildCheckpointTimelineStep('3. City Outer Toll Gate (18.6 km)', 'CURRENT LOCATION 🚛 • 09:10 AM', isCurrent: true),
                          _buildCheckpointTimelineStep('4. Target Fair Price Shop Gate (31.0 km)', 'DESTINATION 🎯 • ETA 09:35 AM', isPending: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right Column: Telemetry Specs & Field Officer Actions
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Live Telemetry Card
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
                              Icon(Icons.analytics_outlined, color: _govNavy, size: 18),
                              SizedBox(width: 8),
                              Text('Live Truck Telemetry Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTelemetryMetricRow('Carrier Truck ID:', _selectedTruckId, isBold: true),
                          _buildTelemetryMetricRow('Target FPS:', _selectedFpsId, isBold: true),
                          _buildTelemetryMetricRow('Driver Phone:', '+91 98450 12345'),
                          _buildTelemetryMetricRow('Cargo Load:', '4,500 kg Fortified Rice'),
                          _buildTelemetryMetricRow('Current Speed:', '42.0 km/h'),
                          _buildTelemetryMetricRow('Distance Remaining:', '12.4 km'),
                          _buildTelemetryMetricRow('ETA Arrival:', '25 Mins (09:35 AM)', valueColor: _govGreen),
                          const Divider(height: 16),
                          const Text('VRP Optimized Route Savings:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: _buildSavingsBadge('18.4 km', 'Distance Saved', Icons.route_rounded)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildSavingsBadge('4.2 L', 'Fuel Saved', Icons.local_gas_station_rounded)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inspector Action Control Panel
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
                              Icon(Icons.touch_app_rounded, color: _govNavy, size: 18),
                              SizedBox(width: 8),
                              Text('Inspector Field Action Controls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isTruckActioning ? null : _handleAdvanceCheckpoint,
                              icon: const Icon(Icons.fast_forward_rounded, size: 14),
                              label: const Text('Advance Checkpoint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isTruckActioning ? null : _handleVerifyArrivalGPS,
                              icon: const Icon(Icons.gps_fixed_rounded, size: 14),
                              label: const Text('Verify Geofence GPS Arrival', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isTruckActioning ? null : _handleReportDelay,
                                  style: OutlinedButton.styleFrom(foregroundColor: _amberAlert, side: const BorderSide(color: _amberAlert)),
                                  child: const Text('Report Delay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isTruckActioning ? null : _handleConfirmDelivery,
                                  style: ElevatedButton.styleFrom(backgroundColor: _govGreen, foregroundColor: Colors.white),
                                  child: const Text('Confirm Goods', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointTimelineStep(String title, String status, {bool isDone = false, bool isCurrent = false, bool isPending = false}) {
    final Color color = isDone ? _govGreen : (isCurrent ? _amberAlert : _slate500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_circle_rounded : (isCurrent ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded), size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500, color: _slate900)),
                Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetricRow(String label, String val, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _slate500)),
          Text(val, style: TextStyle(fontSize: 11.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? _slate900)),
        ],
      ),
    );
  }

  Widget _buildSavingsBadge(String val, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF86EFAC))),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _govGreen),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govGreen)),
              Text(label, style: const TextStyle(fontSize: 9.5, color: _slate500)),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 2: Statutory 6-Point Audit Checklist
  Widget _buildStatutoryChecklistTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Shop Info Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _slate200),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: _govGreen, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CURRENT AUDIT TARGET: ${_selectedFps?.name ?? _selectedFpsId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                      Text('Code: $_selectedFpsId • District: ${_selectedFps?.district ?? "Bengaluru Urban"} • Stock: ${_selectedFps?.currentInventoryTotalKg.toStringAsFixed(0) ?? "1,500"} kg', style: const TextStyle(fontSize: 11, color: _slate500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _complianceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _complianceColor),
                  ),
                  child: Text(
                    'Score: ${_complianceScore.toStringAsFixed(0)}% ($_complianceRating)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _complianceColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Statutory 6-Point Digital Audit Checklist (Legal Metrology & ECA 1955 Standards):',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _slate900),
          ),
          const SizedBox(height: 10),

          // 6 Cards
          _buildChecklistCard(
            1,
            'Weigher Scale Electronic Calibration Certificate Valid',
            'Legal Metrology Act 2009 Sec 24 • Electronic scale tested with 10 kg standard weight within ±0.05% tolerance limit.',
            _scaleCertified,
            (val) => setState(() => _scaleCertified = val),
          ),
          _buildChecklistCard(
            2,
            'Daily Statutory Stock Board Display Updated Outside Shop',
            'Karnataka PDS Control Order Sec 4 • Opening stock, commodity retail rates, and working hours displayed legibly at entrance.',
            _displayBoardUpdated,
            (val) => setState(() => _displayBoardUpdated = val),
          ),
          _buildChecklistCard(
            3,
            'Sample Grain Quality Verification (Moisture < 12%)',
            'PDS FAQ Quality Norms • Fortified Rice and Wheat samples tested free of pest infestation and moisture conformed < 12.0%.',
            _stockMatchesRegister,
            (val) => setState(() => _stockMatchesRegister = val),
          ),
          _buildChecklistCard(
            4,
            'CCTV Security Recording Feed Active & Stored (30-Day Backup)',
            'Transparency Directive • Operational camera covering weighing balance & citizen disbursal queue with 30-day DVR log.',
            _cctvFunctional,
            (val) => setState(() => _cctvFunctional = val),
          ),
          _buildChecklistCard(
            5,
            'Biometric e-PoS Terminal Responsive & Online',
            'Tech Audit Standard • POS terminal connected via 4G network with clean, calibrated optical fingerprint sensor.',
            _eposOnline,
            (val) => setState(() => _eposOnline = val),
          ),
          _buildChecklistCard(
            6,
            'Physical Register vs e-PoS Ledger Audit Aligned',
            'Essential Commodities Act Sec 3 • Physical grain bag tally in warehouse matches electronic inventory balances with zero variance.',
            _hygieneCompliant,
            (val) => setState(() => _hygieneCompliant = val),
          ),
          const SizedBox(height: 16),

          // Quick Jump to Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(4),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Proceed to Sign & Submit Audit Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _govNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(int num, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value ? const Color(0xFF86EFAC) : const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: value ? _govGreen : _dangerRed,
            child: Text('$num', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: value ? _govGreen : _dangerRed)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: _slate500)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: _govGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // TAB 3: Quality Test & Seizure Memo
  Widget _buildQualityTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.science_outlined, color: _govNavy, size: 20),
                    SizedBox(width: 8),
                    Text('Field Grain Quality Testing Sandbox (Moisture & Weigher Test)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                  ],
                ),
                const SizedBox(height: 12),

                // Moisture Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sample Grain Moisture Content: ${_moisturePercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _moisturePercentage <= 12.0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_moisturePercentage <= 12.0 ? '✓ PASS (< 12.0%)' : '❌ EXCEEDS LIMIT (> 12.0%)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _moisturePercentage <= 12.0 ? _govGreen : _dangerRed)),
                    ),
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
                const SizedBox(height: 12),

                // Weigher Scale Error Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Electronic Scale Deviation Error: ±${_scaleErrorGrams.toStringAsFixed(1)}g', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _scaleErrorGrams <= 5.0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_scaleErrorGrams <= 5.0 ? '✓ WITHIN TOLERANCE (±5g)' : '❌ SHORT-WEIGHING DEFECT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _scaleErrorGrams <= 5.0 ? _govGreen : _dangerRed)),
                    ),
                  ],
                ),
                Slider(
                  value: _scaleErrorGrams,
                  min: 0.0,
                  max: 100.0,
                  divisions: 100,
                  activeColor: _scaleErrorGrams <= 5.0 ? _govGreen : _dangerRed,
                  onChanged: (val) => setState(() => _scaleErrorGrams = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Seizure Memo Form
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: _dangerRed, size: 20),
                    const SizedBox(width: 8),
                    const Text('Official Seizure & Regulatory Notice (ECA Sec 6A)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                    const Spacer(),
                    Checkbox(
                      value: _issueSeizureNotice,
                      activeColor: _dangerRed,
                      onChanged: (val) => setState(() => _issueSeizureNotice = val ?? false),
                    ),
                    const Text('Issue Notice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (_issueSeizureNotice) ...[
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (val) => _seizureReason = val,
                    decoration: InputDecoration(
                      hintText: 'Enter statutory ground for grain seizure / notice issuance...',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFFFF1F2),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _dangerRed)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: Inspection Ledger & Submit
  Widget _buildInspectionLedgerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Remarks Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Inspector Observations & Audit Findings:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _slate900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildTemplateChip('✓ All Sacks Weighed'),
                    _buildTemplateChip('✓ Moisture Compliant'),
                    _buildTemplateChip('✓ Scale Stamp Certified'),
                    _buildTemplateChip('⚠️ Minor Variance Found'),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _remarksController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _slate50,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleSubmitReport,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.verified_user_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Sealing Report...' : 'SUBMIT OFFICIAL INSPECTION REPORT FOR $_selectedFpsId'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _govGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Recently Sealed Inspections Ledger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recently Registered Inspection Ledger:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
              Text('${_completedInspections.length} Sealed Certificates', style: const TextStyle(fontSize: 11, color: _slate500)),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
            child: _completedInspections.isEmpty
                ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No historical inspections registered yet in database', style: TextStyle(fontSize: 12, color: _slate500))))
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
                        leading: const Icon(Icons.verified_rounded, color: _govGreen, size: 20),
                        title: Text('ID: ${item['inspection_id']} • Shop: ${item['fps_id']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text('Score: ${score.toStringAsFixed(0)}% • Date: ${item['created_at'] ?? "2026-09-16"}', style: const TextStyle(fontSize: 11, color: _slate500)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                          child: const Text('SEALED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _slate700)),
      backgroundColor: _slate100,
      padding: EdgeInsets.zero,
      onPressed: () {
        final current = _remarksController.text;
        _remarksController.text = '$current $text.';
      },
    );
  }
}

class _GisMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final paintGrid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    // Grid Lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Route Path (Godown -> Current -> Destination)
    final path = Path();
    path.moveTo(60, size.height - 60);
    path.quadraticBezierTo(120, size.height - 120, 195, 125);
    path.quadraticBezierTo(260, 80, size.width - 60, 70);

    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
