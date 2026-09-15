import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';
import 'digital_gatepass_dialog.dart';
import 'fps_predispatch_inspector_dialog.dart';
import '../beneficiary/demo_login_screen.dart';

class FieldOfficerDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const FieldOfficerDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<FieldOfficerDashboardScreen> createState() =>
      _FieldOfficerDashboardScreenState();
}

class _FieldOfficerDashboardScreenState
    extends State<FieldOfficerDashboardScreen> {
  late final ApiService _apiService;
  bool _isLoading = true;
  bool _isAdvancing = false;
  bool _isActionLoading = false;
  List<DigitalGatepass> _gatepasses = [];
  List<TruckRouteTracking> _trackings = [];
  int _selectedIdx = 0;
  String _selectedTruckId = 'TRK-KA-0001';

  // Fallback demo queue if API returns empty
  final List<Map<String, dynamic>> _fallbackQueue = [
    {
      'gatepassId': 'GP-2026-09-001',
      'truckId': 'TRK-KA-0001',
      'driverName': 'Ramesh Kumar (DL-KA01-2018-9912)',
      'fpsDestination': 'FPS-KA-BLR-001 (Malleshwaram Center 1)',
      'commodity': 'Wheat (15.0 MT)',
      'bay': 'Bay #3',
      'status': 'EN_ROUTE',
      'stageIndex': 4,
    },
    {
      'gatepassId': 'GP-2026-09-002',
      'truckId': 'TRK-KA-0002',
      'driverName': 'Suresh Gowda (DL-KA02-2015-4410)',
      'fpsDestination': 'FPS-KA-BLR-002 (Rajajinagar Store)',
      'commodity': 'Rice (20.0 MT)',
      'bay': 'Bay #1',
      'status': 'EN_ROUTE',
      'stageIndex': 4,
    },
    {
      'gatepassId': 'GP-2026-09-003',
      'truckId': 'TRK-KA-0003',
      'driverName': 'Venkatesh Naidu (DL-KA05-2020-1104)',
      'fpsDestination': 'FPS-KA-BLR-005 (Indiranagar Shop)',
      'commodity': 'Wheat (10.0 MT) + Rice (10.0 MT)',
      'bay': 'Bay #2',
      'status': 'LOADING_VERIFIED',
      'stageIndex': 3,
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final gps = await _apiService.fetchAllGatepasses(cycleId: '2026-09');
      List<TruckRouteTracking> tracks = [];
      try {
        tracks = await _apiService.fetchActiveTruckTrackings(cycleId: '2026-09');
      } catch (e) {
        debugPrint('Tracking fetch error: $e');
      }

      if (mounted) {
        setState(() {
          _gatepasses = gps;
          _trackings = tracks;
          if (_trackings.isNotEmpty) {
            // keep current selected truck if valid, otherwise first
            final exists = _trackings.any((t) => t.truckId == _selectedTruckId);
            if (!exists) {
              _selectedTruckId = _trackings.first.truckId;
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRestrictedActionAlert(String actionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('Access Restricted (Separation of Duties)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Separation of Duties Enforced:\n\n'
          'As a Field Officer, your operational authority is strictly limited to physical loading bay operations, '
          'Digital Gatepass clearance, and live checkpoint tracking.\n\n'
          '$actionName is a policy-level planning decision restricted to the District Supply Officer (DSO).',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF92400E)),
            child: const Text('Understood', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _advanceActiveGatepass() async {
    if (_gatepasses.isNotEmpty && _selectedIdx < _gatepasses.length) {
      final gp = _gatepasses[_selectedIdx];
      final currentStage = _getStageIndex(gp.status);
      String nextStatus;
      if (currentStage == 1) {
        nextStatus = 'BAY_ASSIGNED';
      } else if (currentStage == 2) {
        nextStatus = 'LOADING_IN_PROGRESS';
      } else if (currentStage == 3) {
        nextStatus = 'DISPATCH_CONFIRMED';
      } else {
        nextStatus = 'DRIVER_AUTHENTICATED';
      }

      setState(() => _isAdvancing = true);
      try {
        final updated =
            await _apiService.advanceGatepassStage(gp.gatepassId, nextStatus);
        if (mounted) {
          setState(() {
            _gatepasses[_selectedIdx] = updated;
            _isAdvancing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Gatepass ${gp.gatepassId} advanced to $nextStatus!'),
              backgroundColor: const Color(0xFF15803D),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadAllData(); // Refresh tracking layer
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isAdvancing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // Fallback local advance
      final item = _fallbackQueue[_selectedIdx % _fallbackQueue.length];
      int currentStage = item['stageIndex'] as int;
      setState(() {
        if (currentStage < 4) {
          item['stageIndex'] = currentStage + 1;
          item['status'] = currentStage == 1
              ? 'BAY_ASSIGNED'
              : (currentStage == 2
                  ? 'LOADING_IN_PROGRESS'
                  : 'DISPATCH_CONFIRMED');
        } else {
          item['stageIndex'] = 1;
          item['status'] = 'DRIVER_AUTHENTICATED';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gatepass advanced for ${item['truckId']}'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _advanceTruckCheckpoint(String truckId) async {
    setState(() => _isActionLoading = true);
    try {
      final updated = await _apiService.advanceTruckCheckpoint(truckId);
      if (mounted) {
        setState(() {
          final idx = _trackings.indexWhere((t) => t.truckId == truckId);
          if (idx != -1) {
            _trackings[idx] = updated;
          }
          _isActionLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🚚 $truckId advanced to checkpoint: ${updated.currentCheckpoint}'),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReportDelayDialog(String truckId) {
    int delayMins = 20;
    final reasonCtrl = TextEditingController(text: 'Traffic congestion on highway detour');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text('Report Delay: $truckId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Delay Duration:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [15, 20, 30, 45].map((m) {
                  final isSel = delayMins == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('+$m min'),
                      selected: isSel,
                      selectedColor: const Color(0xFFFEF3C7),
                      onSelected: (val) {
                        if (val) setDlgState(() => delayMins = m);
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text('Operational Reason / Cause:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'e.g., Road maintenance, bridge speed restriction',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                setState(() => _isActionLoading = true);
                try {
                  final updated = await _apiService.reportTruckDelay(
                    truckId,
                    delayMinutes: delayMins,
                    reason: reasonCtrl.text.trim(),
                  );
                  if (mounted) {
                    setState(() {
                      final idx = _trackings.indexWhere((t) => t.truckId == truckId);
                      if (idx != -1) _trackings[idx] = updated;
                      _isActionLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ Delay reported for $truckId (+${delayMins}m). Updated ETA: ${updated.eta}'),
                        backgroundColor: const Color(0xFFD97706),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isActionLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error reporting delay: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              child: const Text('Submit Delay Alert', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDeviationDialog(String truckId) {
    final reasonCtrl = TextEditingController(text: 'Detour via Ring Road due to local flyover repair');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.alt_route_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text('Report Route Deviation: $truckId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flag unscheduled corridor detour or unexpected navigation change.',
              style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text('Deviation Rationale:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'e.g., Unscheduled detour due to road maintenance',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isActionLoading = true);
              try {
                final updated = await _apiService.reportTruckDeviation(
                  truckId,
                  reason: reasonCtrl.text.trim(),
                );
                if (mounted) {
                  setState(() {
                    final idx = _trackings.indexWhere((t) => t.truckId == truckId);
                    if (idx != -1) _trackings[idx] = updated;
                    _isActionLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🚨 Route deviation flagged for $truckId!'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isActionLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Flag Deviation', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArrival(String truckId) async {
    setState(() => _isActionLoading = true);
    try {
      final updated = await _apiService.confirmTruckArrival(truckId);
      if (mounted) {
        setState(() {
          final idx = _trackings.indexWhere((t) => t.truckId == truckId);
          if (idx != -1) _trackings[idx] = updated;
          _isActionLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Physical arrival confirmed for $truckId at Destination FPS!'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelivery(String truckId) async {
    setState(() => _isActionLoading = true);
    try {
      final updated = await _apiService.confirmTruckDelivery(truckId);
      if (mounted) {
        setState(() {
          final idx = _trackings.indexWhere((t) => t.truckId == truckId);
          if (idx != -1) _trackings[idx] = updated;
          _isActionLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Grain unloading & delivery completed for $truckId!'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int _getStageIndex(String status) {
    switch (status) {
      case 'DRIVER_AUTHENTICATED':
        return 1;
      case 'BAY_ASSIGNED':
        return 2;
      case 'LOAD_VERIFIED':
      case 'LOADING_IN_PROGRESS':
        return 3;
      case 'DISPATCH_CONFIRMED':
      case 'EXITED':
        return 4;
      default:
        return 1;
    }
  }

  TruckRouteTracking? _getCurrentSelectedTracking() {
    if (_trackings.isEmpty) return null;
    return _trackings.firstWhere(
      (t) => t.truckId == _selectedTruckId,
      orElse: () => _trackings.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLive = _gatepasses.isNotEmpty;
    final String activeTruckId = hasLive
        ? _gatepasses[_selectedIdx].truckId
        : _fallbackQueue[_selectedIdx % _fallbackQueue.length]['truckId']
            as String;
    final String activeDriver = hasLive
        ? _gatepasses[_selectedIdx].driverName
        : _fallbackQueue[_selectedIdx % _fallbackQueue.length]['driverName']
            as String;
    final String activeBay = hasLive
        ? _gatepasses[_selectedIdx].loadingBay
        : _fallbackQueue[_selectedIdx % _fallbackQueue.length]['bay'] as String;
    final String activeStatus = hasLive
        ? _gatepasses[_selectedIdx].status
        : _fallbackQueue[_selectedIdx % _fallbackQueue.length]['status']
            as String;
    final int activeStage = _getStageIndex(activeStatus);

    final TruckRouteTracking? currentTracking = _getCurrentSelectedTracking();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF92400E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 18),
                SizedBox(width: 8),
                Text(
                  'Field Officer Workspace',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              'Physical Execution & Loading Bay Clearance • ${widget.username ?? "field_officer_user"}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFFFDE68A)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Workspace & Tracking',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadAllData,
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
              );
            },
            icon: const Icon(Icons.people_alt_outlined,
                size: 16, color: Colors.white),
            label: const Text('Switch Role',
                style: TextStyle(fontSize: 12, color: Colors.white)),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () {
              _apiService.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WORKSPACE BANNER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: Color(0xFF92400E), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PHYSICAL EXECUTION AUTHORITY • GODOWN & LOADING BAY',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'On-the-ground physical handshake. Confirms that what was planned in the sealed manifest matches physical truck loading. Policy decisions (Forecast locking & Quota overrides) are restricted to enforce CAG audit separation of duties.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF78350F),
                        height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const DigitalGatepassDialog()),
                        icon: const Icon(Icons.qr_code_2_rounded,
                            size: 16, color: Colors.white),
                        label: const Text('Scan QR Gatepass',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showRestrictedActionAlert(
                            'Triggering AI Forecast Pipeline'),
                        icon: const Icon(Icons.lock_outline,
                            size: 14, color: Color(0xFF92400E)),
                        label: const Text('AI Forecast (Restricted)',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF92400E))),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showRestrictedActionAlert(
                            'Overriding Fair Price Shop Quota Allocation'),
                        icon: const Icon(Icons.lock_outline,
                            size: 14, color: Color(0xFF92400E)),
                        label: const Text('Quota Override (Restricted)',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF92400E))),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // =========================================================
            // PHASE 14A: LIVE TRUCK ROUTE TRACKING SECTION
            // =========================================================
            _buildLiveRouteTrackingSection(currentTracking),

            const SizedBox(height: 16),

            // DIGITAL GATEPASS STEPPER CONSOLE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Digital QR Gatepass Pipeline',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'ACTIVE TRUCK: $activeTruckId',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4-Stage Visual Stepper
                  Row(
                    children: [
                      _buildGatepassStep(
                          1, 'Auth', 'Driver Identity', activeStage >= 1),
                      _buildStepLine(activeStage > 1),
                      _buildGatepassStep(
                          2, 'Bay Assign', activeBay, activeStage >= 2),
                      _buildStepLine(activeStage > 2),
                      _buildGatepassStep(
                          3, 'Loading', 'Grain Seal', activeStage >= 3),
                      _buildStepLine(activeStage > 3),
                      _buildGatepassStep(
                          4, 'Exit QR', 'Dispatch Clear', activeStage >= 4),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Active Truck Details
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                            'Driver Name', activeDriver, Icons.person_outline),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoCard(
                            'Assigned Bay', activeBay, Icons.warehouse_outlined),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoCard('Current Status', activeStatus,
                            Icons.local_shipping_outlined),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isAdvancing ? null : _advanceActiveGatepass,
                        icon: _isAdvancing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_forward_rounded,
                                size: 16, color: Colors.white),
                        label: Text(
                          activeStage < 4
                              ? 'Advance Gatepass to Stage ${activeStage + 1}'
                              : 'Re-verify Exit Clearance',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const FpsPreDispatchInspectorDialog(
                                fpsId: 'FPS-KA-BLR-001'),
                          );
                        },
                        icon: const Icon(Icons.fact_check_outlined, size: 16),
                        label: const Text(
                            'Inspect Physical Manifest vs Grain Weight'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // GODOWN LOADING BAY QUEUE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Godown Loading Bay Dispatch Queue',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textPrimary),
                      ),
                      if (_isLoading)
                        const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select a truck to inspect physical loading or link to live route tracking',
                    style: TextStyle(
                        fontSize: 12, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  if (hasLive)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _gatepasses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final gp = _gatepasses[idx];
                        final isSelected = idx == _selectedIdx;
                        final stage = _getStageIndex(gp.status);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIdx = idx;
                              _selectedTruckId = gp.truckId;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFFBEB)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFD97706)
                                    : AppConstants.cardBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_shipping_rounded,
                                  color: isSelected
                                      ? const Color(0xFFD97706)
                                      : AppConstants.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${gp.truckId} • ${gp.driverName}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? const Color(0xFF92400E)
                                              : AppConstants.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Gatepass: ${gp.gatepassId} • Bay: ${gp.loadingBay}',
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppConstants.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'STAGE $stage: ${gp.status}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB45309)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _fallbackQueue.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final item = _fallbackQueue[idx];
                        final isSelected = idx == _selectedIdx;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIdx = idx;
                              _selectedTruckId = item['truckId'] as String;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFFBEB)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFD97706)
                                    : AppConstants.cardBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_shipping_rounded,
                                  color: isSelected
                                      ? const Color(0xFFD97706)
                                      : AppConstants.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item['truckId']} • ${item['driverName']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? const Color(0xFF92400E)
                                              : AppConstants.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Destination: ${item['fpsDestination']}',
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppConstants.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'STAGE ${item['stageIndex']}: ${item['status']}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB45309)),
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
      ),
    );
  }

  // =========================================================================
  // LIVE TRUCK ROUTE TRACKING CARD & TIMELINE COMPONENT
  // =========================================================================
  Widget _buildLiveRouteTrackingSection(TruckRouteTracking? tracking) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fmd_good_rounded,
                        color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Truck Route Tracking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Persistent Field Movement & Checkpoint Pipeline',
                        style: TextStyle(
                            fontSize: 11, color: AppConstants.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_outlined, size: 12, color: Color(0xFF0369A1)),
                    SizedBox(width: 4),
                    Text(
                      'DEMO-SAFE TELEMETRY (DB BACKED)',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0369A1)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Truck Selection Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'TRK-KA-0001',
                'TRK-KA-0002',
                'TRK-KA-0003',
                'TRK-KA-01-EA-9912'
              ].map((truckId) {
                final isSel = _selectedTruckId == truckId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSel,
                    showCheckmark: false,
                    avatar: Icon(Icons.local_shipping,
                        size: 14,
                        color: isSel ? Colors.white : const Color(0xFF0369A1)),
                    label: Text(
                      truckId,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF0284C7),
                    onSelected: (val) {
                      setState(() {
                        _selectedTruckId = truckId;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          if (tracking == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(height: 8),
                  Text('Loading live route telemetry for $_selectedTruckId...',
                      style: const TextStyle(
                          fontSize: 12, color: AppConstants.textSecondary)),
                ],
              ),
            ),
          ] else ...[
            // Status & Delay/Deviation Banner
            if (tracking.delayStatus == 'DELAYED' ||
                tracking.routeDeviationStatus == 'DEVIATED')
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tracking.delayStatus == 'DELAYED'
                                ? '⚠️ DELAY DETECTED: +${tracking.delayMinutes} min'
                                : '🚨 ROUTE DEVIATION FLAGGED',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B)),
                          ),
                          Text(
                            'Reason: ${tracking.delayReason ?? tracking.deviationReason ?? "Traffic congestion"} • Updated ETA: ${tracking.eta}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF7F1D1D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Route Header Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.alt_route_rounded,
                              size: 16, color: Color(0xFF0284C7)),
                          const SizedBox(width: 6),
                          Text(
                            tracking.assignedRoute,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      _buildStatusBadge(tracking.currentStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Text('🟢', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tracking.originGodown,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppConstants.textSecondary),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            const Text('🔵', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tracking.destinationFps,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
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

            const SizedBox(height: 12),

            // Key Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Travelled / Total',
                    '${tracking.distanceTravelledKm.toStringAsFixed(1)} / ${tracking.totalDistanceKm.toStringAsFixed(1)} km',
                    Icons.straighten_rounded,
                    const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Remaining',
                    '${tracking.distanceRemainingKm.toStringAsFixed(1)} km',
                    Icons.trending_down_rounded,
                    const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Dynamic ETA',
                    tracking.eta,
                    Icons.timer_outlined,
                    const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Driver',
                    tracking.driverName.split(' ').first,
                    Icons.person_pin_circle_outlined,
                    const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Visual Checkpoint Timeline
            const Text(
              'Sequential Route Checkpoints',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),

            _buildCheckpointTimeline(tracking),

            const SizedBox(height: 16),

            // Action Buttons for Field Officer
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ||
                            tracking.currentStatus == 'COMPLETED' ||
                            tracking.currentStatus == 'DELIVERED'
                        ? null
                        : () => _advanceTruckCheckpoint(tracking.truckId),
                    icon: _isActionLoading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.skip_next_rounded,
                            size: 16, color: Colors.white),
                    label: const Text('Advance Checkpoint',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showReportDelayDialog(tracking.truckId),
                  icon: const Icon(Icons.alarm_add_rounded,
                      size: 14, color: Color(0xFFD97706)),
                  label: const Text('Report Delay',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFD97706))),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showReportDeviationDialog(tracking.truckId),
                  icon: const Icon(Icons.alt_route_rounded,
                      size: 14, color: Color(0xFFDC2626)),
                  label: const Text('Report Deviation',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
                ),
                const SizedBox(width: 8),
                if (tracking.currentStatus == 'ARRIVED_AT_DESTINATION' ||
                    tracking.currentStatus == 'EN_ROUTE')
                  ElevatedButton.icon(
                    onPressed: _isActionLoading
                        ? null
                        : () => _confirmArrival(tracking.truckId),
                    icon: const Icon(Icons.where_to_vote_rounded,
                        size: 14, color: Colors.white),
                    label: const Text('Confirm Arrival',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                    ),
                  ),
                if (tracking.currentStatus == 'ARRIVED_AT_DESTINATION')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ElevatedButton.icon(
                      onPressed: _isActionLoading
                          ? null
                          : () => _confirmDelivery(tracking.truckId),
                      icon: const Icon(Icons.check_circle_outline,
                          size: 14, color: Colors.white),
                      label: const Text('Complete Delivery',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckpointTimeline(TruckRouteTracking tracking) {
    final checkpoints = tracking.checkpoints;
    if (checkpoints.isEmpty) {
      return const Text('No checkpoints registered for this route.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: checkpoints.length,
      itemBuilder: (context, idx) {
        final cp = checkpoints[idx];
        final isCompleted = cp.status == 'COMPLETED';
        final isCurrent = cp.status == 'IN_PROGRESS';
        final isPending = cp.status == 'PENDING';
        final isLast = idx == checkpoints.length - 1;

        Color circleColor = Colors.grey.shade300;
        Widget iconWidget = const Text('○',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold));

        if (cp.type == 'ORIGIN' && isCompleted) {
          circleColor = const Color(0xFF15803D);
          iconWidget = const Text('🟢', style: TextStyle(fontSize: 10));
        } else if (isCompleted) {
          circleColor = const Color(0xFF15803D);
          iconWidget = const Icon(Icons.check, size: 12, color: Colors.white);
        } else if (isCurrent) {
          circleColor = const Color(0xFF0284C7);
          iconWidget = const Icon(Icons.local_shipping,
              size: 12, color: Colors.white);
        } else if (cp.type == 'DESTINATION') {
          circleColor = isCompleted ? const Color(0xFF15803D) : const Color(0xFF64748B);
          iconWidget = const Text('🔵', style: TextStyle(fontSize: 10));
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: circleColor,
                  child: iconWidget,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 28,
                    color: isCompleted
                        ? const Color(0xFF15803D)
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                cp.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isCurrent
                                      ? const Color(0xFF0369A1)
                                      : (isCompleted
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF334155)),
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('CURRENT POSITION',
                                      style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0369A1))),
                                ),
                            ],
                          ),
                          Text(
                            '${cp.distanceKm.toStringAsFixed(1)} km from origin • ${cp.type}',
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: AppConstants.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      cp.actualTime ?? cp.estimatedTime ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? const Color(0xFF15803D)
                            : (isCurrent
                                ? const Color(0xFF0284C7)
                                : AppConstants.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFE0F2FE);
    Color fg = const Color(0xFF0369A1);

    if (status == 'ARRIVED_AT_DESTINATION' ||
        status == 'DELIVERED' ||
        status == 'COMPLETED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'LOADING' || status == 'LOADING_VERIFIED') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildMetricTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 9.5, color: AppConstants.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGatepassStep(
      int stepNum, String title, String subtitle, bool isDone) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor:
                isDone ? const Color(0xFFD97706) : Colors.grey.shade300,
            child: Text(
              '$stepNum',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDone ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDone ? const Color(0xFF92400E) : Colors.grey.shade600,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 9.5, color: AppConstants.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isDone) {
    return Container(
      width: 20,
      height: 2,
      color: isDone ? const Color(0xFFD97706) : Colors.grey.shade300,
    );
  }

  Widget _buildInfoCard(String label, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppConstants.textSecondary)),
                Text(val,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
