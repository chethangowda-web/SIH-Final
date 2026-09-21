import 'package:flutter/material.dart';
import '../../../models/inspector/inspector_models.dart';

/// Stage 07: Submit & Cryptographically Seal Inspection View
/// Final 7-Point Statutory Readiness Verification • SHA-256 Immutability Commitment
class Stage07SubmitSealView extends StatelessWidget {
  final InspectorTarget target;
  final bool geofenceVerified;
  final bool isSubmitting;
  final VoidCallback onSubmitAndSeal;
  final double complianceScore;
  final String selectedFinding;
  final bool issueSeizureNotice;
  final int evidenceCount;

  const Stage07SubmitSealView({
    super.key,
    required this.target,
    required this.geofenceVerified,
    required this.isSubmitting,
    required this.onSubmitAndSeal,
    required this.complianceScore,
    required this.selectedFinding,
    required this.issueSeizureNotice,
    required this.evidenceCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stage Header
          _buildStageHeader(),
          const SizedBox(height: 16),

          // 2. Readiness Verification Checklist
          Expanded(
            child: ListView(
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.rule, size: 20, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Text(
                              'Pre-Submission Statutory Readiness Checklist',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildReadinessItem('1. Target Fair Price Shop identity authenticated in database master', true),
                        _buildReadinessItem('2. Physical arrival verified within 50m statutory geofence perimeter', geofenceVerified),
                        _buildReadinessItem('3. Inbound truck delivery and consignment quantity inspected', true),
                        _buildReadinessItem('4. Physical stock counts and factual variances computed', true),
                        _buildReadinessItem('5. e-PoS hardware diagnostic ping and biometric connectivity verified', true),
                        _buildReadinessItem('6. Scale calibration error and grain moisture readings recorded', true),
                        _buildReadinessItem('7. Statutory photographic evidence attached to official ledger', evidenceCount > 0, optionalNote: evidenceCount == 0 ? 'No evidence attached' : '$evidenceCount items registered'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Statutory Legal Declaration & Seal Commitment Box
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_user, color: Color(0xFF2563EB), size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Cryptographic Immutability Commitment',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'By submitting this inspection, you affirm under the Essential Commodities Act, 1955 and National Food Security Act, 2013 that all recorded measurements, checklist points, and findings reflect true on-site physical observations. Upon submission, a 256-bit SHA-256 digital seal will be permanently committed to the central compliance ledger.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                'Finding: $selectedFinding',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                'Score: ${complianceScore.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ),
                            if (issueSeizureNotice) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: const Text(
                                  'SEIZURE NOTICE INCLUDED',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock, size: 20),
                    label: Text(
                      isSubmitting ? 'GENERATING SHA-256 SEAL & COMMITTING...' : 'SUBMIT & CRYPTOGRAPHICALLY SEAL INSPECTION',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isSubmitting ? null : onSubmitAndSeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.lock, color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAGE 07 — SUBMIT & CRYPTOGRAPHICALLY SEAL INSPECTION',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Verify full 7-point readiness checklist and permanently seal inspection report with tamper-proof SHA-256 digest',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadinessItem(String title, bool isReady, {String? optionalNote}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: isReady ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isReady ? FontWeight.w600 : FontWeight.w400,
                color: isReady ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ),
          if (optionalNote != null)
            Text(
              optionalNote,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }
}
