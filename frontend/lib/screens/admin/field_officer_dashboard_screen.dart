import 'package:flutter/material.dart';
import '../../core/constants.dart';
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
  int _activeGatepassStage = 1; // 1: Driver Auth, 2: Bay Assignment, 3: Weight Loading, 4: Exit QR
  String _selectedTruckId = 'TRK-KA-01-EA-9912';

  final List<Map<String, dynamic>> _truckQueue = [
    {
      'truckId': 'TRK-KA-01-EA-9912',
      'driverName': 'Ramesh Kumar',
      'fpsDestination': 'FPS-KA-BLR-001 (Malleshwaram Center 1)',
      'commodity': 'Wheat (15.0 MT)',
      'bay': 'Bay #3',
      'status': 'LOADING',
      'stageIndex': 3,
    },
    {
      'truckId': 'TRK-KA-02-FB-4410',
      'driverName': 'Suresh Gowda',
      'fpsDestination': 'FPS-KA-BLR-002 (Rajajinagar Store)',
      'commodity': 'Rice (20.0 MT)',
      'bay': 'Bay #1',
      'status': 'BAY_ASSIGNED',
      'stageIndex': 2,
    },
    {
      'truckId': 'TRK-KA-05-MC-1104',
      'driverName': 'Venkatesh Naidu',
      'fpsDestination': 'FPS-KA-BLR-005 (Indiranagar Shop)',
      'commodity': 'Wheat (10.0 MT) + Rice (10.0 MT)',
      'bay': 'Pending',
      'status': 'AUTHENTICATED',
      'stageIndex': 1,
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
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
          'Separation of Duties Enforced:\n\nAs a Field Officer, your operational authority is strictly limited to physical loading bay operations and Digital Gatepass clearance.\n\n$actionName is a policy level decision restricted to the District Supply Officer (DSO).',
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

  void _advanceGatepass() {
    setState(() {
      if (_activeGatepassStage < 4) {
        _activeGatepassStage++;
      } else {
        _activeGatepassStage = 1;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gatepass Stage advanced to Stage $_activeGatepassStage for $_selectedTruckId'),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTruck = _truckQueue.firstWhere(
      (t) => t['truckId'] == _selectedTruckId,
      orElse: () => _truckQueue.first,
    );

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
                        onPressed: () => _showRestrictedActionAlert('Triggering AI Forecast'),
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
                          'ACTIVE TRUCK: $_selectedTruckId',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4-Stage Visual Stepper
                  Row(
                    children: [
                      _buildGatepassStep(1, 'Auth', 'Driver Identity', _activeGatepassStage >= 1),
                      _buildStepLine(_activeGatepassStage > 1),
                      _buildGatepassStep(2, 'Bay Assign', 'Bay #3', _activeGatepassStage >= 2),
                      _buildStepLine(_activeGatepassStage > 2),
                      _buildGatepassStep(3, 'Loading', 'Grain Seal', _activeGatepassStage >= 3),
                      _buildStepLine(_activeGatepassStage > 3),
                      _buildGatepassStep(4, 'Exit QR', 'Dispatch Clear', _activeGatepassStage >= 4),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Active Truck Details
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard('Driver Name', activeTruck['driverName'] as String, Icons.person_outline),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoCard('Assigned Bay', activeTruck['bay'] as String, Icons.warehouse_outlined),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoCard('Commodity', activeTruck['commodity'] as String, Icons.inventory_2_outlined),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _advanceGatepass,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        label: Text(
                          _activeGatepassStage < 4 ? 'Advance Gatepass to Stage ${_activeGatepassStage + 1}' : 'Reset Gatepass Cycle',
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
                  const Text(
                    'Godown Loading Bay Dispatch Queue',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select a truck to inspect physical loading or advance gatepass status',
                    style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _truckQueue.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = _truckQueue[idx];
                      final isSelected = item['truckId'] == _selectedTruckId;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedTruckId = item['truckId'] as String;
                            _activeGatepassStage = item['stageIndex'] as int;
                          });
                        },
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
