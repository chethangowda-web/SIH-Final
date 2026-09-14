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
  State<FieldOfficerDashboardScreen> createState() => _FieldOfficerDashboardScreenState();
}

class _FieldOfficerDashboardScreenState extends State<FieldOfficerDashboardScreen> {
  late final ApiService _apiService;
  bool _isLoading = true;
  bool _isAdvancing = false;
  List<DigitalGatepass> _gatepasses = [];
  int _selectedIdx = 0;

  // Fallback demo queue if API returns empty
  final List<Map<String, dynamic>> _fallbackQueue = [
    {
      'gatepassId': 'GP-2026-09-001',
      'truckId': 'TRK-KA-01-EA-9912',
      'driverName': 'Ramesh Kumar (DL-KA01-2018-9912)',
      'fpsDestination': 'FPS-KA-BLR-001 (Malleshwaram Center 1)',
      'commodity': 'Wheat (15.0 MT)',
      'bay': 'Bay #3',
      'status': 'LOADING_IN_PROGRESS',
      'stageIndex': 3,
    },
    {
      'gatepassId': 'GP-2026-09-002',
      'truckId': 'TRK-KA-02-FB-4410',
      'driverName': 'Suresh Gowda (DL-KA02-2015-4410)',
      'fpsDestination': 'FPS-KA-BLR-002 (Rajajinagar Store)',
      'commodity': 'Rice (20.0 MT)',
      'bay': 'Bay #1',
      'status': 'BAY_ASSIGNED',
      'stageIndex': 2,
    },
    {
      'gatepassId': 'GP-2026-09-003',
      'truckId': 'TRK-KA-05-MC-1104',
      'driverName': 'Venkatesh Naidu (DL-KA05-2020-1104)',
      'fpsDestination': 'FPS-KA-BLR-005 (Indiranagar Shop)',
      'commodity': 'Wheat (10.0 MT) + Rice (10.0 MT)',
      'bay': 'Pending Assignment',
      'status': 'DRIVER_AUTHENTICATED',
      'stageIndex': 1,
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadGatepasses();
  }

  Future<void> _loadGatepasses() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.fetchAllGatepasses(cycleId: '2026-09');
      if (mounted) {
        setState(() {
          _gatepasses = res;
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
            Text('Access Restricted (Separation of Duties)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Separation of Duties Enforced:\n\nAs a Field Officer, your operational authority is strictly limited to physical loading bay operations and Digital Gatepass clearance.\n\n$actionName is a policy-level planning decision restricted to the District Supply Officer (DSO).',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _advanceActiveGatepass() async {
    if (_gatepasses.isNotEmpty && _selectedIdx < _gatepasses.length) {
      final gp = _gatepasses[_selectedIdx];
      String nextStatus;
      if (gp.status == 'CREATED' || gp.status == 'PENDING') {
        nextStatus = 'DRIVER_AUTHENTICATED';
      } else if (gp.status == 'DRIVER_AUTHENTICATED') {
        nextStatus = 'BAY_ASSIGNED';
      } else if (gp.status == 'BAY_ASSIGNED') {
        nextStatus = 'LOAD_VERIFIED';
      } else if (gp.status == 'LOAD_VERIFIED' || gp.status == 'LOADING_IN_PROGRESS') {
        nextStatus = 'DISPATCH_CONFIRMED';
      } else {
        nextStatus = 'DISPATCH_CONFIRMED';
      }

      setState(() => _isAdvancing = true);
      try {
        final updated = await _apiService.advanceGatepassStage(gp.gatepassId, nextStatus);
        if (mounted) {
          setState(() {
            _gatepasses[_selectedIdx] = updated;
            _isAdvancing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gatepass ${gp.gatepassId} advanced to $nextStatus!'),
              backgroundColor: const Color(0xFF15803D),
              behavior: SnackBarBehavior.floating,
            ),
          );
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
          item['status'] = currentStage == 1 ? 'BAY_ASSIGNED' : (currentStage == 2 ? 'LOADING_IN_PROGRESS' : 'DISPATCH_CONFIRMED');
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

  @override
  Widget build(BuildContext context) {
    final bool hasLive = _gatepasses.isNotEmpty;
    final String activeTruckId = hasLive ? _gatepasses[_selectedIdx].truckId : _fallbackQueue[_selectedIdx % _fallbackQueue.length]['truckId'] as String;
    final String activeDriver = hasLive ? _gatepasses[_selectedIdx].driverName : _fallbackQueue[_selectedIdx % _fallbackQueue.length]['driverName'] as String;
    final String activeBay = hasLive ? _gatepasses[_selectedIdx].loadingBay : _fallbackQueue[_selectedIdx % _fallbackQueue.length]['bay'] as String;
    final String activeStatus = hasLive ? _gatepasses[_selectedIdx].status : _fallbackQueue[_selectedIdx % _fallbackQueue.length]['status'] as String;
    final int activeStage = _getStageIndex(activeStatus);

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
            tooltip: 'Refresh Queue',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadGatepasses,
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
              );
            },
            icon: const Icon(Icons.people_alt_outlined, size: 16, color: Colors.white),
            label: const Text('Switch Role', style: TextStyle(fontSize: 12, color: Colors.white)),
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
                      Icon(Icons.shield_outlined, color: Color(0xFF92400E), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PHYSICAL EXECUTION AUTHORITY • GODOWN & LOADING BAY',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'On-the-ground physical handshake. Confirms that what was planned in the sealed manifest matches physical truck loading. Policy decisions (Forecast locking & Quota overrides) are restricted to enforce CAG audit separation of duties.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF78350F), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => showDialog(context: context, builder: (_) => const DigitalGatepassDialog()),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.white),
                        label: const Text('Scan QR Gatepass', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showRestrictedActionAlert('Triggering AI Forecast Pipeline'),
                        icon: const Icon(Icons.lock_outline, size: 14, color: Color(0xFF92400E)),
                        label: const Text('AI Forecast (Restricted)', style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'ACTIVE TRUCK: $activeTruckId',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4-Stage Visual Stepper
                  Row(
                    children: [
                      _buildGatepassStep(1, 'Auth', 'Driver Identity', activeStage >= 1),
                      _buildStepLine(activeStage > 1),
                      _buildGatepassStep(2, 'Bay Assign', activeBay, activeStage >= 2),
                      _buildStepLine(activeStage > 2),
                      _buildGatepassStep(3, 'Loading', 'Grain Seal', activeStage >= 3),
                      _buildStepLine(activeStage > 3),
                      _buildGatepassStep(4, 'Exit QR', 'Dispatch Clear', activeStage >= 4),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Active Truck Details
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard('Driver Name', activeDriver, Icons.person_outline),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoCard('Assigned Bay', activeBay, Icons.warehouse_outlined),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoCard('Current Status', activeStatus, Icons.local_shipping_outlined),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isAdvancing ? null : _advanceActiveGatepass,
                        icon: _isAdvancing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        label: Text(
                          activeStage < 4 ? 'Advance Gatepass to Stage ${activeStage + 1}' : 'Re-verify Exit Clearance',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => FpsPreDispatchInspectorDialog(fpsId: 'FPS-KA-BLR-001'),
                          );
                        },
                        icon: const Icon(Icons.fact_check_outlined, size: 16),
                        label: const Text('Inspect Physical Manifest vs Grain Weight'),
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
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                      ),
                      if (_isLoading)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select a truck to inspect physical loading or advance gatepass status',
                    style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
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
                          onTap: () => setState(() => _selectedIdx = idx),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFD97706) : AppConstants.cardBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_shipping_rounded,
                                  color: isSelected ? const Color(0xFFD97706) : AppConstants.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${gp.truckId} • ${gp.driverName}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? const Color(0xFF92400E) : AppConstants.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Gatepass: ${gp.gatepassId} • Bay: ${gp.loadingBay}',
                                        style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'STAGE $stage: ${gp.status}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
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
                          onTap: () => setState(() => _selectedIdx = idx),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFD97706) : AppConstants.cardBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_shipping_rounded,
                                  color: isSelected ? const Color(0xFFD97706) : AppConstants.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item['truckId']} • ${item['driverName']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? const Color(0xFF92400E) : AppConstants.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Destination: ${item['fpsDestination']}',
                                        style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'STAGE ${item['stageIndex']}: ${item['status']}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
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

  Widget _buildGatepassStep(int stepNum, String title, String subtitle, bool isDone) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isDone ? const Color(0xFFD97706) : Colors.grey.shade300,
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
            style: const TextStyle(fontSize: 9.5, color: AppConstants.textSecondary),
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
                Text(label, style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
