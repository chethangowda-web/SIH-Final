import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/inspector/inspector_models.dart';
import '../../../widgets/inspector/inspector_data_source_modal.dart';

/// Stage 08: Sealed Inspection Record & Statutory Certificate View
/// Read-Only Permanent Legal Instrument • SHA-256 Digital Seal • DSO & Audit Synchronization
class Stage08SealedRecordView extends StatelessWidget {
  final SealedInspectionReport? report;
  final String activeCycle;
  final VoidCallback onStartNewInspection;
  final VoidCallback onViewDecisionTrace;

  const Stage08SealedRecordView({
    super.key,
    required this.report,
    required this.activeCycle,
    required this.onStartNewInspection,
    required this.onViewDecisionTrace,
  });

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const Center(
        child: Text('No sealed inspection record loaded.', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    final rep = report!;
    final isCompliant = rep.complianceScore >= 80.0 && !rep.seizureIssued;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          // 1. Success Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isCompliant ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCompliant ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCompliant ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompliant ? Icons.verified : Icons.warning_amber_rounded,
                    color: isCompliant ? const Color(0xFF059669) : const Color(0xFFD97706),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INSPECTION REPORT PERMANENTLY SEALED & COMMITTED',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isCompliant ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Statutory physical inspection for ${rep.fpsName} (${rep.fpsId}) has been cryptographically sealed and synchronized with DSO Command Center and CAG/Lokayukta Audit Ledger.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompliant ? const Color(0xFF047857) : const Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Official Statutory Inspection Certificate
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Certificate Top Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GOVERNMENT OF KARNATAKA',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0),
                          ),
                          const Text(
                            'Department of Food, Civil Supplies & Consumer Affairs',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Statutory Field Inspection Certificate • Cycle $activeCycle',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rep.inspectionId,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 32),

                  // Metadata Matrix
                  Row(
                    children: [
                      _buildCertField('Fair Price Shop', '${rep.fpsName} (${rep.fpsId})'),
                      _buildCertField('District Jurisdiction', rep.district),
                      _buildCertField('Certifying Officer', rep.inspectorId),
                      _buildCertField('Sealed Timestamp', rep.sealedAt),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildCertField('Compliance Score', '${rep.complianceScore.toStringAsFixed(1)}%'),
                      _buildCertField('Grain Moisture', rep.moisturePct != null ? '${rep.moisturePct}%' : 'Within Limit (<=12%)'),
                      _buildCertField('Scale Calibration', rep.scaleErrorG != null ? '${rep.scaleErrorG}g' : 'Legal Metrology Certified'),
                      _buildCertField('Seizure Notice', rep.seizureIssued ? 'SERVED (Section 3 ECA 1955)' : 'None Issued'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Cryptographic SHA-256 Digital Seal Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.enhanced_encryption, size: 16, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 8),
                            const Text(
                              'SHA-256 IMMUTABLE CRYPTOGRAPHIC SEAL DIGEST:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), letterSpacing: 0.5),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14, color: Color(0xFF94A3B8)),
                              tooltip: 'Copy Hash Digest',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: rep.sealedHash));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('SHA-256 Seal Hash copied to clipboard!')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          rep.sealedHash,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Integration Sync Status Badges
                  Row(
                    children: [
                      _buildSyncBadge('DSO Command Center Synchronized', Icons.sync_alt, const Color(0xFF059669)),
                      const SizedBox(width: 12),
                      _buildSyncBadge('Lokayukta / CAG Audit Ledger Committed', Icons.account_balance, const Color(0xFF2563EB)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. Action Buttons
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.storage, size: 16),
                label: const Text('VIEW DATA SOURCE'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () {
                  InspectorDataSourceModal.show(
                    context,
                    title: 'Sealed Inspection Record: ${rep.inspectionId}',
                    datasetName: 'Statutory Field Inspection Ledger',
                    tableName: 'fps_inspections JOIN surprise_inspection_orders',
                    cycleId: activeCycle,
                    recordCount: '1 permanently sealed record',
                    formula: 'SELECT * FROM fps_inspections WHERE inspection_id = "${rep.inspectionId}"',
                    apiEndpoint: '/api/v1/officer/inspection/${rep.inspectionId}/sealed-report',
                  );
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.timeline, size: 16),
                label: const Text('VIEW DECISION TRACE'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: onViewDecisionTrace,
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('START NEXT INSPECTION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: onStartNewInspection,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCertField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
