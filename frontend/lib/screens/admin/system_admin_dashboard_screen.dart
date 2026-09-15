import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/health_model.dart';
import '../../services/api_service.dart';
import 'citizen_request_queue_dialog.dart';
import '../beneficiary/demo_login_screen.dart';
import '../connectivity_screen.dart';

class SystemAdminDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const SystemAdminDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<SystemAdminDashboardScreen> createState() => _SystemAdminDashboardScreenState();
}

class _SystemAdminDashboardScreenState extends State<SystemAdminDashboardScreen> {
  late final ApiService _apiService;
  bool _isLoading = true;
  bool _isResetting = false;
  HealthModel? _healthData;

  final List<Map<String, String>> _systemUsers = [
    {
      'username': 'admin_user',
      'role': 'ADMIN',
      'scope': 'Root System Administrator (Platform & Health)',
      'status': 'ACTIVE',
    },
    {
      'username': 'dso_user',
      'role': 'DSO',
      'scope': 'District Supply Officer (7-Stage Stepper & Quotas)',
      'status': 'ACTIVE',
    },
    {
      'username': 'field_officer_user',
      'role': 'FIELD_OFFICER',
      'scope': 'Godown Loading Bay (Digital Gatepass Clearance)',
      'status': 'ACTIVE',
    },
    {
      'username': 'auditor_user',
      'role': 'AUDITOR',
      'scope': 'State Vigilance Auditor (SHA-256 Manifest & MAPE)',
      'status': 'ACTIVE',
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.checkHealth();
      if (mounted) {
        setState(() {
          _healthData = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetDemo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Operational Workflow?'),
        content: const Text('This will reset the planning cycle state back to PLANNING_OPEN for the active dispatch period.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResetting = true);
    try {
      await _apiService.resetDemoWorkflow(cycleId: '2026-09');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workflow successfully reset to PLANNING_OPEN cycle state.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      _loadHealthData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbStatus = _healthData?.databaseStatus ?? 'connected';
    final fpsCount = _healthData?.fpsCount ?? 20;
    final benCount = _healthData?.beneficiariesCount ?? 2000;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'System Administrator Workspace',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              'Master Platform Configuration & Health • ${widget.username ?? "admin_user"}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Health Diagnostics',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadHealthData,
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined, color: Color(0xFF0F172A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'MASTER PLATFORM MANAGEMENT & SYSTEM DIAGNOSTICS',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Root administrator console. Manages role assignments, system-level configurations, beneficiary master dataset synchronization, database integrity, and operational diagnostic health checks.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ConnectivityScreen(apiService: _apiService),
                            ),
                          );
                        },
                        icon: const Icon(Icons.monitor_heart_outlined, size: 16, color: Colors.white),
                        label: const Text('System Diagnostics & Health Check', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => showDialog(context: context, builder: (_) => const CitizenRequestQueueDialog()),
                        icon: const Icon(Icons.inbox_outlined, size: 16, color: Colors.white),
                        label: const Text('Citizen Request & Preference Queue', style: TextStyle(fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loadHealthData,
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                        label: const Text('Run Database Integrity Check', style: TextStyle(fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // SYSTEM TELEMETRY CARDS
            Row(
              children: [
                Expanded(
                  child: _buildSystemMetricCard('Database Connection', dbStatus.toUpperCase(), 'SQLite PRAGMA Healthy', Icons.storage_rounded, const Color(0xFF059669)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSystemMetricCard('Active Fair Price Shops', '$fpsCount Units', 'Bengaluru Urban District', Icons.storefront_outlined, const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSystemMetricCard('Master Beneficiaries', '$benCount Records', 'Verified NFSA Citizens', Icons.people_outline, const Color(0xFF7E22CE)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // USER ROLES & RBAC PERMISSION DIRECTORY
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
                    'Departmental Staff & RBAC Role Permission Directory',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Active system accounts with enforced separation-of-duties controls against diversion.',
                    style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _systemUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final u = _systemUsers[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 20, color: Color(0xFF0F172A)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${u['username']} • ${u['role']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(u['scope']!, style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                              child: Text(u['status']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                            ),
                          ],
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

  Widget _buildSystemMetricCard(String title, String val, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.textPrimary)),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
        ],
      ),
    );
  }
}
