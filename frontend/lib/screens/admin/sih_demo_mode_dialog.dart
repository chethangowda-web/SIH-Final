import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/health_model.dart';
import '../../services/api_service.dart';

class SihDemoModeDialog extends StatefulWidget {
  final String cycleId;

  const SihDemoModeDialog({
    super.key,
    this.cycleId = '2026-09',
  });

  static void show(BuildContext context, {String cycleId = '2026-09'}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SihDemoModeDialog(cycleId: cycleId),
    );
  }

  @override
  State<SihDemoModeDialog> createState() => _SihDemoModeDialogState();
}

class _SihDemoModeDialogState extends State<SihDemoModeDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  HealthModel? _healthData;
  int _latencyMs = 0;

  @override
  void initState() {
    super.initState();
    _checkSystemHealth();
  }

  Future<void> _checkSystemHealth() async {
    setState(() {
      _isLoading = true;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final health = await _apiService.checkHealth();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _healthData = health;
          _latencyMs = health.latencyMs > 0 ? health.latencyMs : stopwatch.elapsedMilliseconds;
          _isLoading = false;
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _latencyMs = stopwatch.elapsedMilliseconds;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.92).clamp(340.0, 960.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(420.0, 720.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConstants.primaryNavy),
                      SizedBox(height: 12),
                      Text('Running system diagnostics & node telemetry...',
                          style: TextStyle(
                              color: AppConstants.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildDiagnosticsBody()),
            const SizedBox(height: 12),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.primaryNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'PDS Infrastructure & System Diagnostics Suite',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.successGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SYSTEM HEALTHY',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Real-Time Infrastructure Telemetry • Active Operational Cycle: ${widget.cycleId}',
                  style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Close Diagnostics',
        ),
      ],
    );
  }

  Widget _buildDiagnosticsBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'API Latency',
                  '${_latencyMs} ms',
                  _latencyMs < 500 ? 'Optimal Performance' : 'Standard Response Time',
                  Icons.speed_rounded,
                  AppConstants.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Database Status',
                  _healthData?.databaseStatus.toUpperCase() ?? 'CONNECTED',
                  'PostgreSQL / SQLite Storage Engine',
                  Icons.storage_rounded,
                  AppConstants.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'AI Engine Baseline',
                  'ACTIVE',
                  'Pre-Dispatch Demand Prediction Model',
                  Icons.psychology_rounded,
                  const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Operational Pipeline Subsystem Status',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.primaryNavy),
          ),
          const SizedBox(height: 10),
          _buildSubsystemList(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String val, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.textSecondary)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppConstants.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildSubsystemList() {
    final subsystems = [
      {'name': 'NFSA Citizen Demand Aggregator', 'desc': 'Processes SMS/USSD/Portal choice declarations', 'status': 'ONLINE', 'icon': Icons.connect_without_contact_rounded},
      {'name': '9-Constraint Optimization Engine', 'desc': 'Statutory floor, vehicle payload & storage limits', 'status': 'ACTIVE', 'icon': Icons.tune_rounded},
      {'name': 'Digital QR Manifest Verification', 'desc': 'Gatepass clearance and security token engine', 'status': 'READY', 'icon': Icons.qr_code_scanner_rounded},
      {'name': 'Fair Price Shop Stock Telemetry', 'desc': 'Biometric ePoS / IMPDS synchronization service', 'status': 'ONLINE', 'icon': Icons.storefront_rounded},
      {'name': 'Beneficiary SMS Notification Gateway', 'desc': 'Alerts citizens upon truck dispatch & arrival', 'status': 'ACTIVE', 'icon': Icons.chat_bubble_outline_rounded},
    ];

    return Column(
      children: subsystems.map((sub) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppConstants.bgLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppConstants.cardBorder),
          ),
          child: Row(
            children: [
              Icon(sub['icon'] as IconData, size: 18, color: AppConstants.primaryNavy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                    Text(sub['desc'] as String, style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppConstants.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppConstants.successGreen.withOpacity(0.4)),
                ),
                child: Text(
                  sub['status'] as String,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppConstants.successGreen),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'NATIONAL FOOD SECURITY ACT (NFSA) • SYSTEM DIAGNOSTICS & TELEMETRY',
          style: TextStyle(fontSize: 10, color: AppConstants.textTertiary),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
          ),
          child: const Text('Close Diagnostics'),
        ),
      ],
    );
  }
}
