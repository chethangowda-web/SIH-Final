import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';
import 'manifest_management_dialog.dart';
import 'judge_view_dialog.dart';
import '../beneficiary/demo_login_screen.dart';

class AuditorDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const AuditorDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<AuditorDashboardScreen> createState() => _AuditorDashboardScreenState();
}

class _AuditorDashboardScreenState extends State<AuditorDashboardScreen> {
  late final ApiService _apiService;

  final List<Map<String, String>> _sealedManifests = [
    {
      'manifestId': 'MNF-2026-09-001',
      'cycleId': '2026-09',
      'sha256Hash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      'timestamp': '2026-09-01 08:30:14 UTC',
      'sealingOfficer': 'DSO_OFFICER_BLR',
      'status': 'SEALED & VERIFIED',
    },
    {
      'manifestId': 'MNF-2026-09-002',
      'cycleId': '2026-09',
      'sha256Hash': '8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4',
      'timestamp': '2026-09-01 09:15:22 UTC',
      'sealingOfficer': 'DSO_OFFICER_BLR',
      'status': 'SEALED & VERIFIED',
    },
    {
      'manifestId': 'MNF-2026-09-003',
      'cycleId': '2026-09',
      'sha256Hash': 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3',
      'timestamp': '2026-09-01 10:45:00 UTC',
      'sealingOfficer': 'DSO_OFFICER_BLR',
      'status': 'SEALED & VERIFIED',
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
  }

  void _showReadOnlyNotice(String actionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFF6B21A8), size: 22),
            SizedBox(width: 8),
            Text('Read-Only Oversight Role', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Read-Only Governance Layer Enforced:\n\nAs a State Vigilance Auditor, your account operates with strict read-only oversight permissions to review SHA-256 sealed manifests, MAPE error evaluation metrics, and audit logs after the fact.\n\n$actionName is disabled for auditor accounts.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B21A8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 18),
                SizedBox(width: 8),
                Text(
                  'Vigilance Auditor Workspace',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              'Independent Read-Only Oversight • ${widget.username ?? "auditor_user"}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFFE9D5FF)),
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
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF6B21A8), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'INDEPENDENT OVERSIGHT • READ-ONLY GOVERNANCE LAYER',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF6B21A8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Operates after the fact. Reviews SHA-256-sealed manifests, gatepass audit logs, and evaluation/MAPE records. Doesn\'t trigger forecasts, approve overrides, or advance gatepasses — purely independent governance oversight.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF581C87), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => showDialog(context: context, builder: (_) => const JudgeViewDialog()),
                        icon: const Icon(Icons.gavel_rounded, size: 16, color: Colors.white),
                        label: const Text('Audit Trail & Anti-Diversion Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E22CE)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => showDialog(context: context, builder: (_) => ManifestManagementDialog(cycleId: '2026-09')),
                        icon: const Icon(Icons.lock_outlined, size: 14, color: Color(0xFF6B21A8)),
                        label: const Text('Inspect Sealed Manifests', style: TextStyle(fontSize: 12, color: Color(0xFF6B21A8))),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // GOVERNANCE AUDIT METRICS
            Row(
              children: [
                Expanded(
                  child: _buildAuditMetricCard('Sealed Manifests', '3 Active', 'SHA-256 Verified', Icons.verified_rounded, const Color(0xFF059669)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAuditMetricCard('Forecast MAPE Error', '4.12%', 'High Accuracy', Icons.query_stats_rounded, const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAuditMetricCard('Diversion Anomaly Risk', '0.00%', 'Zero Tampering', Icons.security_rounded, const Color(0xFF7E22CE)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // SHA-256 SEALED MANIFEST AUDIT TABLE
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
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SHA-256 Sealed Manifest Governance Records',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                      ),
                      Chip(
                        label: Text('READ-ONLY OVERSIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8))),
                        backgroundColor: Color(0xFFF3E8FF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sealedManifests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = _sealedManifests[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item['manifestId']} • Cycle ${item['cycleId']}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['status']!,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SHA-256 Hash: ${item['sha256Hash']}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppConstants.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Sealed By: ${item['sealingOfficer']}', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                                Text(item['timestamp']!, style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                              ],
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

  Widget _buildAuditMetricCard(String title, String val, String sub, IconData icon, Color color) {
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
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.textPrimary)),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
        ],
      ),
    );
  }
}
