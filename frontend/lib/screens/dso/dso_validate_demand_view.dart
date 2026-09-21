import 'package:flutter/material.dart';
import '../../services/dso/dso_service.dart';

class DsoValidateDemandView extends StatefulWidget {
  final DsoService dsoService;
  final String cycleId;
  final VoidCallback onValidatedSuccess;

  const DsoValidateDemandView({
    super.key,
    required this.dsoService,
    required this.cycleId,
    required this.onValidatedSuccess,
  });

  @override
  State<DsoValidateDemandView> createState() => _DsoValidateDemandViewState();
}

class _DsoValidateDemandViewState extends State<DsoValidateDemandView> {
  bool _loading = true;
  bool _validating = false;
  Map<String, dynamic>? _snapData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.dsoService.getDemandValidation(cycleId: widget.cycleId);
      setState(() {
        _snapData = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleValidateSeal() async {
    setState(() => _validating = true);
    try {
      final res = await widget.dsoService.validateDemand(
        cycleId: widget.cycleId,
        officerName: 'Dr. S. Kumar',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demand Sealed! SHA-256 Hash: ${res['canonical_hash']}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      widget.onValidatedSuccess();
      await _loadSnapshot();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Validation failed: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Color(0xFFDC2626))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadSnapshot, child: const Text('Retry')),
          ],
        ),
      );
    }

    final data = _snapData ?? {};
    final isSealed = data['is_sealed'] == true;
    final snapshotId = data['snapshot_id'] ?? 'SNAP-2026-09-01';
    final hash = data['canonical_hash'] ?? 'Pending Validation';
    final totals = data['totals'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSealed ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSealed ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Icon(
                  isSealed ? Icons.verified_user : Icons.gavel,
                  color: isSealed ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stage 02: Validate Demand & Seal Snapshot',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSealed
                            ? 'Demand snapshot is SEALED and IMMUTABLE under statutory cryptographic hash.'
                            : 'Review beneficiary intent, forecast projections, and baseline demand before statutory sealing.',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
                if (!isSealed)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: _validating ? null : _handleValidateSeal,
                    child: _validating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            children: const [
                              Icon(Icons.lock, size: 16),
                              SizedBox(width: 8),
                              Text('VALIDATE & SEAL DEMAND', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Snapshot Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Canonical Demand Snapshot Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),

                  _buildDetailRow('Snapshot ID:', snapshotId),
                  _buildDetailRow('SHA-256 Digital Seal:', hash),
                  _buildDetailRow('Validated By:', data['validated_by'] ?? 'District Supply Officer'),
                  _buildDetailRow('Validated At:', data['validated_at'] ?? 'Pending'),
                  _buildDetailRow('Snapshot Status:', isSealed ? 'SEALED & IMMUTABLE' : 'UNSEALED DRAFT'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Demands Comparison Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cycle Demand Totals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _buildTotalCard('Intent Demand', totals['intent_demand_kg'] ?? 124560.0, const Color(0xFF2563EB)),
                      const SizedBox(width: 16),
                      _buildTotalCard('Forecast Demand', totals['forecast_demand_kg'] ?? 118230.0, const Color(0xFF16A34A)),
                      const SizedBox(width: 16),
                      _buildTotalCard('Baseline Demand', totals['baseline_demand_kg'] ?? 103450.0, const Color(0xFFD97706)),
                      const SizedBox(width: 16),
                      _buildTotalCard('Validated Demand', totals['validated_demand_kg'] ?? 118230.0, const Color(0xFF7C3AED)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  Widget _buildTotalCard(String title, dynamic qty, Color color) {
    final double numVal = (qty as num?)?.toDouble() ?? 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Text(
              '${(numVal / 1000.0).toStringAsFixed(1)} MT',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              '${numVal.round()} kg',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
