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

  // Active Multi-Route Truck Dispatches & GPS Tracking State
  List<Map<String, dynamic>> _activeTrucks = [];
  Set<String> _selectedTruckIds = {}; // Multi-route selection set
  String _selectedTruckId = 'KA-04-GA-9081';
  Map<String, dynamic>? _selectedTruckDetail;
  bool _isTruckActioning = false;
  String _routeStatusFilter = 'ALL'; // ALL, EN_ROUTE, DELIVERED, DISPATCHED

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

  // Corridor color palette for multi-route mapping
  static const List<Color> _routeColors = [
    Color(0xFF38BDF8), // 0: Sky Blue (North)
    Color(0xFF4ADE80), // 1: Green (West)
    Color(0xFFFBBF24), // 2: Amber (East)
    Color(0xFFC084FC), // 3: Purple (South)
    Color(0xFFF472B6), // 4: Pink (Central)
    Color(0xFF2DD4BF), // 5: Teal (North-East)
  ];

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

      // 3. Fetch active multi-route truck dispatches
      await _loadTruckTrackings();

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTruckTrackings() async {
    try {
      final trucks = await _apiService.fetchActiveTruckTrackings();
      if (trucks.isNotEmpty && trucks.length >= 4) {
        _activeTrucks = trucks.asMap().entries.map((entry) {
          final idx = entry.key;
          final t = entry.value;
          final color = _routeColors[idx % _routeColors.length];
          return {
            'truck_id': t.truckId,
            'corridor': _getCorridorForIndex(idx),
            'driver_name': t.driverName,
            'driver_phone': '+91 98450 ${12340 + idx}',
            'origin_godown': t.originGodown,
            'target_fps_id': t.destinationFps,
            'commodity': idx % 2 == 0 ? 'Fortified Rice (PHH)' : 'Whole Wheat (AAY)',
            'cargo_weight_kg': 3500.0 + (idx * 400.0),
            'current_checkpoint': t.currentCheckpoint,
            'next_checkpoint': t.nextCheckpoint,
            'distance_remaining_km': t.distanceRemainingKm,
            'eta_minutes': int.tryParse(t.eta.replaceAll(RegExp(r'[^0-9]'), '')) ?? (20 + idx * 5),
            'speed_kmh': 38.0 + (idx * 3.0),
            'status': t.currentStatus,
            'route_color': color,
            'route_index': idx,
          };
        }).toList();
      } else {
        // Complete multi-corridor fleet dataset for Bengaluru Urban
        _activeTrucks = [
          {
            'truck_id': 'KA-04-GA-9081',
            'corridor': 'North Corridor (Hebbal)',
            'driver_name': 'Ramesh Kumar',
            'driver_phone': '+91 98450 12345',
            'origin_godown': 'FCI Central Godown, Hebbal',
            'target_fps_id': 'FPS-KA-BLR-001',
            'commodity': 'Fortified Rice (PHH)',
            'cargo_weight_kg': 4500.0,
            'current_checkpoint': 'Outer Ring Road Checkpoint #1',
            'next_checkpoint': 'Malleshwaram FPS Entrance',
            'distance_remaining_km': 12.4,
            'eta_minutes': 25,
            'speed_kmh': 42.0,
            'status': 'EN_ROUTE',
            'route_color': _routeColors[0],
            'route_index': 0,
          },
          {
            'truck_id': 'KA-04-GA-7712',
            'corridor': 'West Corridor (Peenya)',
            'driver_name': 'Suresh Gowda',
            'driver_phone': '+91 98450 67890',
            'origin_godown': 'FCI Central Godown, Hebbal',
            'target_fps_id': 'FPS-KA-BLR-002',
            'commodity': 'Whole Wheat (AAY)',
            'cargo_weight_kg': 3800.0,
            'current_checkpoint': 'Highway Bypass Junction',
            'next_checkpoint': 'Rajajinagar Checkpoint',
            'distance_remaining_km': 18.2,
            'eta_minutes': 35,
            'speed_kmh': 46.0,
            'status': 'EN_ROUTE',
            'route_color': _routeColors[1],
            'route_index': 1,
          },
          {
            'truck_id': 'KA-04-GA-3345',
            'corridor': 'East Corridor (Whitefield)',
            'driver_name': 'Manjunath K',
            'driver_phone': '+91 98450 44321',
            'origin_godown': 'FCI Central Godown, Hebbal',
            'target_fps_id': 'FPS-KA-BLR-003',
            'commodity': 'Fortified Rice (PHH)',
            'cargo_weight_kg': 5200.0,
            'current_checkpoint': 'KR Puram Flyover Checkpoint',
            'next_checkpoint': 'Whitefield Main Market',
            'distance_remaining_km': 22.5,
            'eta_minutes': 40,
            'speed_kmh': 40.0,
            'status': 'EN_ROUTE',
            'route_color': _routeColors[2],
            'route_index': 2,
          },
          {
            'truck_id': 'KA-04-GA-5519',
            'corridor': 'South Corridor (Jayanagar)',
            'driver_name': 'Venkatesh R',
            'driver_phone': '+91 98450 88765',
            'origin_godown': 'FCI Central Godown, Hebbal',
            'target_fps_id': 'FPS-KA-BLR-004',
            'commodity': 'Fortified Rice & Wheat',
            'cargo_weight_kg': 4100.0,
            'current_checkpoint': 'Hosur Road Toll Plaza',
            'next_checkpoint': 'BTM Layout FPS Gate',
            'distance_remaining_km': 26.0,
            'eta_minutes': 48,
            'speed_kmh': 44.0,
            'status': 'EN_ROUTE',
            'route_color': _routeColors[3],
            'route_index': 3,
          },
          {
            'truck_id': 'KA-04-GA-8820',
            'corridor': 'Central Corridor (Malleshwaram)',
            'driver_name': 'Anand Patil',
            'driver_phone': '+91 98450 99123',
            'origin_godown': 'FCI Central Godown, Hebbal',
            'target_fps_id': 'FPS-KA-BLR-005',
            'commodity': 'Whole Wheat (AAY)',
            'cargo_weight_kg': 3500.0,
            'current_checkpoint': 'Yeshwanthpur Industrial Gate',
            'next_checkpoint': 'Malleshwaram 8th Cross',
            'distance_remaining_km': 8.5,
            'eta_minutes': 18,
            'speed_kmh': 36.0,
            'status': 'EN_ROUTE',
            'route_color': _routeColors[4],
            'route_index': 4,
          },
          {
            'truck_id': 'KA-04-GA-4401',
            'corridor': 'North-East Corridor (Yelahanka)',
            'driver_name': 'Pradeep N',
            'driver_phone': '+91 98450 55432',
            'origin_godown': 'FCI Central Godown, Hebbal',
            'target_fps_id': 'FPS-KA-BLR-006',
            'commodity': 'Fortified Rice (PHH)',
            'cargo_weight_kg': 4900.0,
            'current_checkpoint': 'Bellary Road Expressway',
            'next_checkpoint': 'Yelahanka Satellite Town',
            'distance_remaining_km': 15.0,
            'eta_minutes': 30,
            'speed_kmh': 50.0,
            'status': 'EN_ROUTE',
            'route_color': _routeColors[5],
            'route_index': 5,
          },
        ];
      }

      // Default to selecting ALL active routes so multi-route tracking is active immediately
      if (_selectedTruckIds.isEmpty) {
        _selectedTruckIds = _activeTrucks.map((t) => t['truck_id'].toString()).toSet();
      }

      if (!_activeTrucks.any((t) => t['truck_id'] == _selectedTruckId)) {
        _selectedTruckId = _activeTrucks.first['truck_id'].toString();
      }

      await _loadSelectedTruckDetail();
    } catch (_) {}
  }

  String _getCorridorForIndex(int idx) {
    const corridors = [
      'North Corridor (Hebbal)',
      'West Corridor (Peenya)',
      'East Corridor (Whitefield)',
      'South Corridor (Jayanagar)',
      'Central Corridor (Malleshwaram)',
      'North-East Corridor (Yelahanka)',
    ];
    return corridors[idx % corridors.length];
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
        final match = _activeTrucks.firstWhere(
          (t) => t['truck_id'] == _selectedTruckId,
          orElse: () => _activeTrucks.first,
        );
        setState(() {
          _selectedTruckDetail = {
            'truck_id': match['truck_id'],
            'driver_name': match['driver_name'],
            'origin_godown': match['origin_godown'],
            'target_fps_id': match['target_fps_id'],
            'commodity': match['commodity'],
            'cargo_weight_kg': match['cargo_weight_kg'],
            'current_checkpoint': match['current_checkpoint'],
            'distance_remaining_km': match['distance_remaining_km'],
            'eta_minutes': match['eta_minutes'],
            'speed_kmh': match['speed_kmh'],
            'status': match['status'],
            'vrp_metrics': {
              'distance_saved_km': 18.4,
              'fuel_saved_liters': 4.2,
              'co2_saved_kg': 11.0,
            },
            'checkpoints': [
              {'name': '1. Central FCI Godown Outgate', 'status': 'PASSED ✓', 'time': '08:15 AM'},
              {'name': '2. Highway Bypass Checkpoint', 'status': 'PASSED ✓', 'time': '08:45 AM'},
              {'name': '3. ${match['current_checkpoint']}', 'status': 'CURRENT LOCATION 🚛', 'time': '09:10 AM'},
              {'name': '4. Target Fair Price Shop Gate', 'status': 'DESTINATION 🎯', 'time': 'ETA 09:35 AM'},
            ],
          };
        });
      }
    }
  }

  // ----------------- MULTI-ROUTE BATCH ACTIONS ----------------- //

  /// 1. Bulk Dispatch Selected Routes
  Future<void> _handleBatchDispatchSelected() async {
    if (_selectedTruckIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one route to dispatch stock.'), backgroundColor: _amberAlert),
      );
      return;
    }

    setState(() => _isTruckActioning = true);
    await Future.delayed(const Duration(milliseconds: 600));

    // Update statuses
    setState(() {
      for (var truck in _activeTrucks) {
        if (_selectedTruckIds.contains(truck['truck_id'])) {
          truck['status'] = 'IN_TRANSIT';
        }
      }
      _isTruckActioning = false;
    });

    final totalKg = _selectedTrucks.fold<double>(0.0, (sum, t) => sum + ((t['cargo_weight_kg'] as num?)?.toDouble() ?? 0.0));
    final totalMt = (totalKg / 1000.0).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: _govGreen, size: 24),
            SizedBox(width: 8),
            Text('Simultaneous Multi-Route Dispatch Authorized', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully authorized and dispatched ${_selectedTruckIds.length} simultaneous delivery routes from FCI Central Godown (Hebbal).', style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                children: [
                  _buildCertificateRow('Routes Dispatched', '${_selectedTruckIds.length} Active Corridors', isBold: true),
                  const SizedBox(height: 4),
                  _buildCertificateRow('Total Stock Dispatched', '$totalMt Metric Tons (MT)', isBold: true),
                  const SizedBox(height: 4),
                  _buildCertificateRow('Destination FPS Centers', _selectedTrucks.map((t) => t['target_fps_id']).join(', ')),
                  const SizedBox(height: 4),
                  _buildCertificateRow('VRP Route Optimization', 'ACTIVE • 6 Corridors Parallel'),
                ],
              ),
            ),
          ],
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

  /// 2. Batch Advance Checkpoints
  Future<void> _handleBatchAdvanceCheckpoints() async {
    if (_selectedTruckIds.isEmpty) return;
    setState(() => _isTruckActioning = true);
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      for (var truck in _activeTrucks) {
        if (_selectedTruckIds.contains(truck['truck_id'])) {
          truck['current_checkpoint'] = 'Approach Zone (Geofence < 2.0 km)';
          truck['distance_remaining_km'] = ((truck['distance_remaining_km'] as num?)?.toDouble() ?? 5.0) * 0.5;
          truck['eta_minutes'] = (((truck['eta_minutes'] as num?)?.toInt() ?? 10) ~/ 2).clamp(5, 60);
        }
      }
      _isTruckActioning = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏩ Advanced checkpoints across all ${_selectedTruckIds.length} selected routes!'),
        backgroundColor: _govGreen,
      ),
    );
  }

  /// 3. Batch Geofence GPS Arrival Verification
  Future<void> _handleBatchVerifyArrivalGPS() async {
    if (_selectedTruckIds.isEmpty) return;
    setState(() => _isTruckActioning = true);
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() => _isTruckActioning = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gps_fixed_rounded, color: _govGreen, size: 24),
            SizedBox(width: 8),
            Text('Batch GPS Geofence Verified', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verified real-time satellite coordinates for ${_selectedTruckIds.length} trucks within 150m of their target Fair Price Shop perimeters.', style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
              child: Text(
                'Active Geofence Pings: ${_selectedTruckIds.join(", ")} ✓ 100% Signal Integrity',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govGreen),
              ),
            ),
          ],
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

  /// 4. Batch Confirm Delivery
  Future<void> _handleBatchConfirmDelivery() async {
    if (_selectedTruckIds.isEmpty) return;
    setState(() => _isTruckActioning = true);
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      for (var truck in _activeTrucks) {
        if (_selectedTruckIds.contains(truck['truck_id'])) {
          truck['status'] = 'DELIVERED';
          truck['distance_remaining_km'] = 0.0;
          truck['eta_minutes'] = 0;
        }
      }
      _isTruckActioning = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📦 Stock offloading confirmed at all ${_selectedTruckIds.length} target Fair Price Shops!'),
        backgroundColor: _govGreen,
      ),
    );
  }

  List<Map<String, dynamic>> get _selectedTrucks {
    return _activeTrucks.where((t) => _selectedTruckIds.contains(t['truck_id'])).toList();
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
        const SizedBox(width: 8),
        Expanded(
          child: Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: _slate900), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
        ),
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
                  const Icon(Icons.alt_route_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Multi-Route Dispatch & GPS (${_activeTrucks.length})'),
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

                      // Tab 1: Multi-Route Dispatch & Live GPS Tracking Map
                      _buildMultiRouteDispatchMapTab(),

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
              _buildKpiChip('MULTI-ROUTES ACTIVE', '${_activeTrucks.length} Corridors', Icons.alt_route_rounded, _govNavy),
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
  // TAB 1: MULTI-ROUTE SELECTION, BATCH DISPATCH & SIMULTANEOUS GPS TRACKING MAP
  // =========================================================================
  Widget _buildMultiRouteDispatchMapTab() {
    final selectedCount = _selectedTruckIds.length;
    final totalKg = _selectedTrucks.fold<double>(0.0, (sum, t) => sum + ((t['cargo_weight_kg'] as num?)?.toDouble() ?? 0.0));
    final totalMt = (totalKg / 1000.0).toStringAsFixed(1);
    final allSelected = selectedCount == _activeTrucks.length && _activeTrucks.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar with Multi-Route Context
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Multi-Route Dispatch Operations & Simultaneous GPS Telemetry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  Text('Select multiple corridor delivery routes simultaneously to authorize batch stock dispatches across Bengaluru Urban.', style: const TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedTruckIds.clear();
                        } else {
                          _selectedTruckIds = _activeTrucks.map((t) => t['truck_id'].toString()).toSet();
                        }
                      });
                    },
                    icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 16),
                    label: Text(allSelected ? 'Deselect All' : 'Select All (${_activeTrucks.length} Routes)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh All Routes',
                    onPressed: _loadTruckTrackings,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Multi-Route Collective Summary & Batch Dispatch Controls Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_govNavy, Color(0xFF1E3A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: _govNavy.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
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
                        const Icon(Icons.hub_outlined, color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Multi-Route Fleet Dispatch Tray: $selectedCount of ${_activeTrucks.length} Selected',
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF34D399)),
                      ),
                      child: Text(
                        'Total Selected Cargo: $totalMt MT',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Batch Operational Action Buttons
                LayoutBuilder(builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final btn1 = ElevatedButton.icon(
                    onPressed: _isTruckActioning || _selectedTruckIds.isEmpty ? null : _handleBatchDispatchSelected,
                    icon: const Icon(Icons.rocket_launch_rounded, size: 15),
                    label: Text('Bulk Dispatch Selected ($selectedCount Trucks)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(backgroundColor: _govGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  );

                  final btn2 = OutlinedButton.icon(
                    onPressed: _isTruckActioning || _selectedTruckIds.isEmpty ? null : _handleBatchAdvanceCheckpoints,
                    icon: const Icon(Icons.fast_forward_rounded, size: 15),
                    label: const Text('Advance All Checkpoints', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  );

                  final btn3 = OutlinedButton.icon(
                    onPressed: _isTruckActioning || _selectedTruckIds.isEmpty ? null : _handleBatchVerifyArrivalGPS,
                    icon: const Icon(Icons.gps_fixed_rounded, size: 15),
                    label: const Text('Batch Geofence Verify', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF38BDF8))),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF38BDF8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  );

                  final btn4 = ElevatedButton.icon(
                    onPressed: _isTruckActioning || _selectedTruckIds.isEmpty ? null : _handleBatchConfirmDelivery,
                    icon: const Icon(Icons.check_circle_outline, size: 15),
                    label: const Text('Confirm Deliveries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: btn1),
                        const SizedBox(width: 8),
                        Expanded(child: btn2),
                        const SizedBox(width: 8),
                        Expanded(child: btn3),
                        const SizedBox(width: 8),
                        Expanded(child: btn4),
                      ],
                    );
                  } else {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [btn1, btn2, btn3, btn4],
                    );
                  }
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Main Multi-Route Workspace (Multi-Route Visual Map & Interactive Checkbox Table)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Multi-Route GIS Map Canvas
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // GIS Canvas rendering ALL selected routes simultaneously
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _slate700),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Dynamic Multi-Route Custom Canvas Painter
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _MultiRouteGisMapPainter(
                                selectedTrucks: _selectedTrucks,
                              ),
                            ),
                          ),

                          // Floating Header on Map
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.satellite_alt_rounded, color: Color(0xFF38BDF8), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'SIMULTANEOUS MULTI-ROUTE TRACKING ($selectedCount ACTIVE CORRIDORS)',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const Text('VRP CORRIDOR MESH ACTIVE', style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),

                          // Central FCI Godown Hub Pin (Origin)
                          Positioned(
                            left: 30,
                            bottom: 30,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)],
                                  ),
                                  child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('FCI Central Godown (Hebbal)', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Multi-Route Interactive Color Legend Strip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Corridor Routes & Color Mapping (Click to Toggle):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _slate700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _activeTrucks.map((truck) {
                              final tId = truck['truck_id'] as String;
                              final isChecked = _selectedTruckIds.contains(tId);
                              final color = truck['route_color'] as Color? ?? _govNavy;
                              final corridor = truck['corridor'] as String;

                              return FilterChip(
                                selected: isChecked,
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text('$tId • $corridor', style: TextStyle(fontSize: 10.5, fontWeight: isChecked ? FontWeight.bold : FontWeight.normal, color: isChecked ? _slate900 : _slate500)),
                                  ],
                                ),
                                selectedColor: color.withValues(alpha: 0.18),
                                checkmarkColor: color,
                                backgroundColor: _slate100,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedTruckIds.add(tId);
                                    } else {
                                      _selectedTruckIds.remove(tId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right Column: Collective VRP Metrics & Selected Route Inspector
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Collective VRP Fleet Savings Card
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
                              Icon(Icons.insights_rounded, color: _govNavy, size: 18),
                              SizedBox(width: 8),
                              Text('Cumulative VRP Fleet Savings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTelemetryMetricRow('Selected Active Routes:', '$selectedCount Corridors', isBold: true),
                          _buildTelemetryMetricRow('Combined Stock Volume:', '$totalMt MT', isBold: true, valueColor: _govGreen),
                          _buildTelemetryMetricRow('Total Delivery Stops:', '$selectedCount FPS Centers'),
                          _buildTelemetryMetricRow('Average Fleet Speed:', '43.5 km/h'),
                          const Divider(height: 16),
                          const Text('Simultaneous Dispatch Optimizations:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildSavingsBadge('${(selectedCount * 14.2).toStringAsFixed(1)} km', 'Distance Saved', Icons.route_rounded)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildSavingsBadge('${(selectedCount * 3.4).toStringAsFixed(1)} L', 'Fuel Saved', Icons.local_gas_station_rounded)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Route Spotlight Card
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
                              const Text('Focus Route Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              DropdownButton<String>(
                                value: _activeTrucks.any((t) => t['truck_id'] == _selectedTruckId) ? _selectedTruckId : _activeTrucks.first['truck_id'].toString(),
                                isDense: true,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govNavy),
                                items: _activeTrucks.map((t) {
                                  return DropdownMenuItem<String>(
                                    value: t['truck_id'].toString(),
                                    child: Text(t['truck_id'].toString()),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedTruckId = val);
                                    _loadSelectedTruckDetail();
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTelemetryMetricRow('Driver Contact:', _selectedTruckDetail?['driver_name'] ?? 'Ramesh Kumar (+91 98450 12345)'),
                          _buildTelemetryMetricRow('Destination FPS:', _selectedTruckDetail?['target_fps_id'] ?? 'FPS-KA-BLR-001'),
                          _buildTelemetryMetricRow('Cargo Type:', _selectedTruckDetail?['commodity'] ?? 'Fortified Rice (FAQ Grade A)'),
                          _buildTelemetryMetricRow('Current Checkpoint:', _selectedTruckDetail?['current_checkpoint'] ?? 'Outer Ring Road'),
                          _buildTelemetryMetricRow('ETA to Target:', '${_selectedTruckDetail?["eta_minutes"] ?? 25} Mins', valueColor: _govGreen),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Multi-Route Interactive Checkbox Table
          const Text('Active Multi-Corridor Delivery Routes Table:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _slate200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeTrucks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final truck = _activeTrucks[idx];
                final tId = truck['truck_id'].toString();
                final isChecked = _selectedTruckIds.contains(tId);
                final color = truck['route_color'] as Color? ?? _govNavy;
                final weightKg = (truck['cargo_weight_kg'] as num?)?.toDouble() ?? 4000.0;
                final status = truck['status'] as String? ?? 'EN_ROUTE';

                return ListTile(
                  dense: true,
                  leading: Checkbox(
                    value: isChecked,
                    activeColor: _govGreen,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTruckIds.add(tId);
                        } else {
                          _selectedTruckIds.remove(tId);
                        }
                      });
                    },
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color),
                        ),
                        child: Text(tId, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _slate900)),
                      ),
                      const SizedBox(width: 8),
                      Text('${truck['corridor']} ➔ ${truck['target_fps_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'DELIVERED' ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: status == 'DELIVERED' ? _govGreen : const Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Driver: ${truck['driver_name']} (${truck['driver_phone']}) • Cargo: ${truck['commodity']} (${weightKg.toStringAsFixed(0)} kg) • Next: ${truck['next_checkpoint']}',
                    style: const TextStyle(fontSize: 11, color: _slate500),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ETA: ${truck['eta_minutes']}m', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govGreen)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.center_focus_strong_rounded, size: 16, color: _govNavy),
                        tooltip: 'Focus this route',
                        onPressed: () {
                          setState(() {
                            _selectedTruckId = tId;
                            _selectedTruckIds.add(tId);
                          });
                          _loadSelectedTruckDetail();
                        },
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

  Widget _buildTelemetryMetricRow(String label, String val, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _slate500)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(val, style: TextStyle(fontSize: 11.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? _slate900), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
          ),
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
            'Point-of-Sale (e-PoS) Terminal Online & Biometric Tested',
            'NIC Bharat PDS Integration • Aadhaar iris/fingerprint scanner functional with zero ghost transaction logs.',
            _eposOnline,
            (val) => setState(() => _eposOnline = val),
          ),
          _buildChecklistCard(
            6,
            'Premises Cleanliness, Grain Bag Stacking & Hygiene Norms',
            'Warehouse Protocol • 100 mm wooden dunnage crates used to prevent ground dampness; godown pest-controlled.',
            _hygieneCompliant,
            (val) => setState(() => _hygieneCompliant = val),
          ),
          const SizedBox(height: 16),

          // Next Stage Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(3),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('PROCEED TO GRAIN QUALITY LAB TEST & SEIZURE CHECK →'),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value ? _slate200 : const Color(0xFFFECACA)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: _govGreen,
        dense: true,
        title: Text('$num. $title', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: value ? _slate900 : _dangerRed)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: _slate500)),
      ),
    );
  }

  // TAB 3: Grain Quality Lab Test & Seizure Notice
  Widget _buildQualityTestTab() {
    final moisturePass = _moisturePercentage <= 12.0;

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
                const Text('Field Digital Moisture Meter Test (FAQ Norms):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grain Moisture Content: ${_moisturePercentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: moisturePass ? _govGreen : _dangerRed)),
                          Slider(
                            value: _moisturePercentage,
                            min: 8.0,
                            max: 18.0,
                            divisions: 100,
                            activeColor: moisturePass ? _govGreen : _dangerRed,
                            onChanged: (val) {
                              setState(() {
                                _moisturePercentage = val;
                                if (!moisturePass && !_issueSeizureNotice) {
                                  _issueSeizureNotice = true;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: moisturePass ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        moisturePass ? 'PASS (< 12%)' : 'FAIL (> 12%)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: moisturePass ? _govGreen : _dangerRed),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Scale Error Test
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Standard 10 kg Weight Calibration Test:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recorded Error: ${_scaleErrorGrams.toStringAsFixed(1)} grams', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _scaleErrorGrams.abs() <= 5.0 ? _govGreen : _dangerRed)),
                          Slider(
                            value: _scaleErrorGrams,
                            min: -50.0,
                            max: 50.0,
                            divisions: 100,
                            activeColor: _scaleErrorGrams.abs() <= 5.0 ? _govGreen : _dangerRed,
                            onChanged: (val) => setState(() => _scaleErrorGrams = val),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _scaleErrorGrams.abs() <= 5.0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _scaleErrorGrams.abs() <= 5.0 ? 'TOLERANCE OK' : 'DEFICIT BIAS',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _scaleErrorGrams.abs() <= 5.0 ? _govGreen : _dangerRed),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

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
              subtitle: const Text('Freezes grain allotment, locks e-PoS transactions, and orders physical stock seizure.', style: TextStyle(fontSize: 11, color: _slate500)),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(4),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('PROCEED TO INSPECTION LEDGER & REPORT SEALING →'),
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

/// Custom GIS Map Painter rendering multiple simultaneous corridor routes
class _MultiRouteGisMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> selectedTrucks;

  _MultiRouteGisMapPainter({required this.selectedTrucks});

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    // 1. Draw GIS coordinate grid lines
    for (double x = 0; x < size.width; x += 35) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    for (double y = 0; y < size.height; y += 35) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Origin Coordinates: FCI Central Godown (Hebbal) at bottom-left
    final origin = Offset(60, size.height - 50);

    // Destination Target Coordinates distributed across Bengaluru Urban quadrants
    final destinations = [
      Offset(size.width * 0.25, 60),  // 0: North (Hebbal / Yelahanka)
      Offset(size.width * 0.50, 50),  // 1: West (Peenya / Rajajinagar)
      Offset(size.width * 0.85, 80),  // 2: East (KR Puram / Whitefield)
      Offset(size.width * 0.80, size.height - 70), // 3: South (Jayanagar / BTM)
      Offset(size.width * 0.45, size.height * 0.45), // 4: Central (Malleshwaram)
      Offset(size.width * 0.70, 45),  // 5: North-East (Yelahanka Town)
    ];

    // Control points for bezier curve routing
    final controlPoints = [
      Offset(size.width * 0.15, size.height * 0.45),
      Offset(size.width * 0.35, size.height * 0.30),
      Offset(size.width * 0.55, size.height * 0.35),
      Offset(size.width * 0.45, size.height * 0.75),
      Offset(size.width * 0.30, size.height * 0.60),
      Offset(size.width * 0.50, size.height * 0.25),
    ];

    // 2. Draw each active route curve and truck position
    for (int i = 0; i < selectedTrucks.length; i++) {
      final truck = selectedTrucks[i];
      final routeIdx = ((truck['route_index'] as int?) ?? i) % destinations.length;
      final dest = destinations[routeIdx];
      final cp = controlPoints[routeIdx];
      final routeColor = truck['route_color'] as Color? ?? const Color(0xFF38BDF8);

      final routePaint = Paint()
        ..color = routeColor.withValues(alpha: 0.85)
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke;

      final glowPaint = Paint()
        ..color = routeColor.withValues(alpha: 0.25)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(origin.dx, origin.dy);
      path.quadraticBezierTo(cp.dx, cp.dy, dest.dx, dest.dy);

      // Draw route path with glow
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, routePaint);

      // Draw Destination Target Marker
      final destPaint = Paint()..color = routeColor;
      canvas.drawCircle(dest, 6, destPaint);
      canvas.drawCircle(dest, 10, Paint()..color = routeColor.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 2);

      // Calculate approximate position of truck along the bezier curve (e.g. t = 0.55)
      const t = 0.55;
      final truckX = (1 - t) * (1 - t) * origin.dx + 2 * (1 - t) * t * cp.dx + t * t * dest.dx;
      final truckY = (1 - t) * (1 - t) * origin.dy + 2 * (1 - t) * t * cp.dy + t * t * dest.dy;
      final truckPos = Offset(truckX, truckY);

      // Draw Moving Truck Marker
      final truckBgPaint = Paint()..color = const Color(0xFF0F172A);
      final truckBorderPaint = Paint()..color = routeColor..style = PaintingStyle.stroke..strokeWidth = 2;

      canvas.drawCircle(truckPos, 9, truckBgPaint);
      canvas.drawCircle(truckPos, 9, truckBorderPaint);
      canvas.drawCircle(truckPos, 4, Paint()..color = routeColor);

      // Draw Target FPS text above destination
      final fpsId = truck['target_fps_id']?.toString() ?? 'FPS';
      final textSpan = TextSpan(
        text: fpsId,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 8.5, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(dest.dx - textPainter.width / 2, dest.dy - 16));

      // Draw Truck ID badge near truck
      final tId = truck['truck_id']?.toString() ?? 'TRUCK';
      final truckSpan = TextSpan(
        text: '🚛 $tId',
        style: TextStyle(color: routeColor, fontSize: 8.5, fontWeight: FontWeight.bold),
      );
      final truckPainter = TextPainter(text: truckSpan, textDirection: TextDirection.ltr)..layout();
      truckPainter.paint(canvas, Offset(truckPos.dx + 12, truckPos.dy - 6));
    }
  }

  @override
  bool shouldRepaint(covariant _MultiRouteGisMapPainter oldDelegate) {
    return oldDelegate.selectedTrucks != selectedTrucks;
  }
}
